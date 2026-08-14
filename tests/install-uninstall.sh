#!/usr/bin/env bash

set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"

# Tests must never pick up the developer's own overlay from a sibling directory.
no_private="$test_root/absent-overlay"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    if [ -d "$test_root" ]; then
        case "$(basename "$test_root")" in
            dotfiles-test.*) rm -rf -- "$test_root" ;;
            *) fail "refusing to remove unexpected test path: $test_root" ;;
        esac
    fi
}

assert_link() {
    local target="$1" expected="$2"
    [ -L "$target" ] || fail "$target is not a symbolic link"
    [ "$(readlink "$target")" = "$expected" ] ||
        fail "$target points to $(readlink "$target"), expected $expected"
}

assert_absent() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        fail "$target still exists"
    fi
}

assert_same() {
    local left="$1" right="$2"
    cmp -s "$left" "$right" || fail "$left differs from $right"
}

# The whole point of the prefix indirection: nothing under $HOME may resolve
# into the source checkout.
assert_no_link_into_source() {
    local home="$1" link
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        case "$(readlink "$link")" in
            "$repo" | "$repo"/*) fail "$link resolves into the source checkout" ;;
        esac
    done <<EOF
$(find "$home" -type l 2>/dev/null)
EOF
}

# Without this, an unexpected non-zero exit under set -e ends the run with no
# message at all, which is the worst kind of test failure to debug.
trap 'echo "FAIL: unexpected error at line $LINENO" >&2' ERR
trap cleanup EXIT

# --- fresh installation ------------------------------------------------------

fresh_home="$test_root/fresh-home"
fresh_state="$test_root/fresh-state"
fresh_prefix="$fresh_home/.local/share/dotfiles"
mkdir -p "$fresh_home"

HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/install.sh" --all
assert_link "$fresh_home/.config/git" "$fresh_prefix/git"
assert_link "$fresh_home/.ssh/config" "$fresh_prefix/ssh/config"
assert_absent "$fresh_home/.gnupg/gpg-agent.conf"
assert_no_link_into_source "$fresh_home"

assert_same "$fresh_prefix/git/config" "$repo/config/git/config"
assert_same "$fresh_prefix/git/ignore" "$repo/config/git/ignore"
assert_same "$fresh_prefix/ssh/config" "$repo/config/ssh/config"

# A second installation must leave links intact without creating another backup.
HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/install.sh" --all
assert_link "$fresh_home/.config/git" "$fresh_prefix/git"
assert_link "$fresh_home/.ssh/config" "$fresh_prefix/ssh/config"

# --- update ------------------------------------------------------------------

# A clean tree reports no work and exits zero.
HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" --check >/dev/null ||
    fail "--check reported drift on a freshly installed tree"

# Drift in the installed copy is detected, reported, and repaired.
printf '%s\n' "hand-edited installed copy" >>"$fresh_prefix/git/config"
if HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" --check >/dev/null; then
    fail "--check did not detect a modified installed copy"
fi

HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" >/dev/null
assert_same "$fresh_prefix/git/config" "$repo/config/git/config"

HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" --check >/dev/null ||
    fail "--check still reported drift after update"

# Files that no longer exist in the source are pruned from the installed copy.
printf '%s\n' "orphan" >"$fresh_prefix/git/removed-upstream"
HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" >/dev/null
assert_absent "$fresh_prefix/git/removed-upstream"

# A deleted link is restored without disturbing the installed copy.
unlink "$fresh_home/.ssh/config"
HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" >/dev/null
assert_link "$fresh_home/.ssh/config" "$fresh_prefix/ssh/config"

# --- uninstall ---------------------------------------------------------------

HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/uninstall.sh" --all
assert_absent "$fresh_home/.config/git"
assert_absent "$fresh_home/.ssh/config"
assert_absent "$fresh_prefix"

# The local edit made above was preserved, and uninstall must not delete it:
# it is the user's data, not the installer's. Everything else goes.
[ -f "$fresh_state/dotfiles-installer/backups/local/dotfiles/git/config" ] ||
    fail "a preserved local edit was removed by uninstall"
grep -Fq "hand-edited installed copy" \
    "$fresh_state/dotfiles-installer/backups/local/dotfiles/git/config" ||
    fail "the preserved local edit does not contain what was edited"
[ ! -d "$fresh_state/dotfiles-installer/published" ] ||
    fail "the published manifest outlived the prefix it describes"
[ ! -d "$fresh_state/dotfiles-installer/components" ] ||
    fail "component markers were not removed"

# Update on an empty installation is a no-op, not an error.
HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" >/dev/null || fail "update failed with nothing installed"

# --- an edit to the installed copy is detected and preserved -----------------

# The installer must tell a local edit apart from a stale checkout. Both look
# like "these two files differ"; only the manifest says which side moved.
local_home="$test_root/local-home"
local_state="$test_root/local-state"
local_prefix="$local_home/.local/share/dotfiles"
mkdir -p "$local_home"

run_local() {
    # --check exits non-zero by design, so capture rather than pipe: under
    # pipefail the exit status would mask a successful grep.
    HOME="$local_home" XDG_STATE_HOME="$local_state" \
        DOTFILES_PRIVATE_ROOT="$no_private" "$@" 2>&1 || true
}

run_local "$repo/install.sh" git ssh >/dev/null

# Simulates `git config --global`, which writes through the link into the prefix.
printf '%s\n' "written by a tool through the link" >>"$local_prefix/git/config"

case "$(run_local "$repo/update.sh" --check)" in
    *"would overwrite a local edit"*) ;;
    *) fail "--check did not announce that a local edit would be overwritten" ;;
esac

grep -Fq "written by a tool through the link" "$local_prefix/git/config" ||
    fail "--check modified the installed copy"

case "$(run_local "$repo/update.sh")" in
    *"preserved a local edit"*) ;;
    *) fail "update did not report preserving the local edit" ;;
esac

assert_same "$local_prefix/git/config" "$repo/config/git/config"
grep -Fq "written by a tool through the link" \
    "$local_state/dotfiles-installer/backups/local/dotfiles/git/config" ||
    fail "the local edit was not preserved with its contents"

# A second run has nothing left to preserve and must be quiet about it.
case "$(run_local "$repo/update.sh")" in
    *"preserved a local edit"*) fail "update reported a preserved edit when none existed" ;;
esac

# --- pre-existing configuration is preserved ---------------------------------

existing_home="$test_root/existing-home"
existing_state="$test_root/existing-state"
existing_prefix="$existing_home/.local/share/dotfiles"
mkdir -p "$existing_home/.config/git" "$existing_home/.ssh"
printf '%s\n' "original Git configuration" >"$existing_home/.config/git/config"
printf '%s\n' "original ignore rules" >"$existing_home/.config/git/ignore"
printf '%s\n' "original SSH configuration" >"$existing_home/.ssh/config"

HOME="$existing_home" XDG_STATE_HOME="$existing_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/install.sh" git ssh
assert_link "$existing_home/.config/git" "$existing_prefix/git"
assert_link "$existing_home/.ssh/config" "$existing_prefix/ssh/config"

grep -Fqx "original Git configuration" \
    "$existing_state/dotfiles-installer/backups/.config/git/config" ||
    fail "Git configuration was not preserved"
grep -Fqx "original ignore rules" \
    "$existing_state/dotfiles-installer/backups/.config/git/ignore" ||
    fail "Git ignore rules were not preserved"
grep -Fqx "original SSH configuration" \
    "$existing_state/dotfiles-installer/backups/.ssh/config" ||
    fail "SSH configuration was not preserved"

HOME="$existing_home" XDG_STATE_HOME="$existing_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/uninstall.sh" --all
[ ! -L "$existing_home/.config/git" ] || fail "restored Git configuration is still a link"
[ ! -L "$existing_home/.ssh/config" ] || fail "restored SSH configuration is still a link"
grep -Fqx "original Git configuration" "$existing_home/.config/git/config" ||
    fail "Git configuration was not restored"
grep -Fqx "original ignore rules" "$existing_home/.config/git/ignore" ||
    fail "Git ignore rules were not restored"
grep -Fqx "original SSH configuration" "$existing_home/.ssh/config" ||
    fail "SSH configuration was not restored"
[ ! -d "$existing_state/dotfiles-installer" ] || fail "restore state was not removed"

# --- links from the pre-prefix scheme are adopted, not backed up -------------

legacy_home="$test_root/legacy-home"
legacy_state="$test_root/legacy-state"
legacy_prefix="$legacy_home/.local/share/dotfiles"
mkdir -p "$legacy_home/.config" "$legacy_home/.ssh"
ln -s "$repo/config/git" "$legacy_home/.config/git"
ln -s "$repo/config/ssh/config" "$legacy_home/.ssh/config"

HOME="$legacy_home" XDG_STATE_HOME="$legacy_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/install.sh" git ssh
assert_link "$legacy_home/.config/git" "$legacy_prefix/git"
assert_link "$legacy_home/.ssh/config" "$legacy_prefix/ssh/config"
assert_no_link_into_source "$legacy_home"
assert_absent "$legacy_state/dotfiles-installer/backups/.config/git"
assert_absent "$legacy_state/dotfiles-installer/backups/.ssh/config"

# --- private overlay ---------------------------------------------------------

private_home="$test_root/private-home"
private_state="$test_root/private-state"
private_root="$test_root/private-overlay"
private_prefix="$private_home/.local/share/dotfiles-private"
mkdir -p "$private_home" "$private_root/config/gnupg"
printf '%s\n' "pinentry-program /example/pinentry" >"$private_root/config/gnupg/gpg-agent.conf"

HOME="$private_home" XDG_STATE_HOME="$private_state" DOTFILES_PRIVATE_ROOT="$private_root" \
    "$repo/install.sh" gnupg
assert_link "$private_home/.gnupg/gpg-agent.conf" "$private_prefix/gnupg/gpg-agent.conf"
assert_same "$private_prefix/gnupg/gpg-agent.conf" "$private_root/config/gnupg/gpg-agent.conf"

# The overlay is published from its own checkout, never linked to it.
case "$(readlink "$private_home/.gnupg/gpg-agent.conf")" in
    "$private_root"/*) fail "gnupg link resolves into the overlay checkout" ;;
esac

printf '%s\n' "pinentry-program /example/updated" >"$private_root/config/gnupg/gpg-agent.conf"
HOME="$private_home" XDG_STATE_HOME="$private_state" DOTFILES_PRIVATE_ROOT="$private_root" \
    "$repo/update.sh" >/dev/null
assert_same "$private_prefix/gnupg/gpg-agent.conf" "$private_root/config/gnupg/gpg-agent.conf"

HOME="$private_home" XDG_STATE_HOME="$private_state" DOTFILES_PRIVATE_ROOT="$private_root" \
    "$repo/uninstall.sh" gnupg
assert_absent "$private_home/.gnupg/gpg-agent.conf"
assert_absent "$private_prefix"

# --- doctor reports the state of a real installation -------------------------

doc_home="$test_root/doctor-home"
doc_state="$test_root/doctor-state"
doc_prefix="$doc_home/.local/share/dotfiles"
mkdir -p "$doc_home"

run_doc() {
    HOME="$doc_home" XDG_STATE_HOME="$doc_state" DOTFILES_PRIVATE_ROOT="$no_private" \
        "$@" 2>&1 || true
}

doc_status() {
    HOME="$doc_home" XDG_STATE_HOME="$doc_state" DOTFILES_PRIVATE_ROOT="$no_private" \
        "$repo/doctor.sh" >/dev/null 2>&1
    echo "$?"
}

case "$(run_doc "$repo/doctor.sh")" in
    *"Nothing is installed"*) ;;
    *) fail "doctor did not report an empty installation" ;;
esac

run_doc "$repo/install.sh" git ssh >/dev/null
case "$(run_doc "$repo/doctor.sh")" in
    *"looks healthy"*) ;;
    *) fail "doctor did not pass a fresh installation" ;;
esac
[ "$(doc_status)" -eq 0 ] || fail "doctor exited non-zero on a healthy installation"

# A missing link must be reported and must fail the exit status.
unlink "$doc_home/.ssh/config"
case "$(run_doc "$repo/doctor.sh")" in
    *"is missing. Run ./update.sh"*) ;;
    *) fail "doctor did not report a missing link" ;;
esac
[ "$(doc_status)" -ne 0 ] || fail "doctor exited zero with a missing link"
run_doc "$repo/update.sh" >/dev/null

# A link back into the checkout breaks the rule the design rests on.
unlink "$doc_home/.config/git"
ln -s "$repo/config/git" "$doc_home/.config/git"
case "$(run_doc "$repo/doctor.sh")" in
    *"resolves into a checkout"*) ;;
    *) fail "doctor did not report a link into the checkout" ;;
esac
run_doc "$repo/install.sh" git ssh >/dev/null

# An edit written into the prefix is a warning, not a failure: nothing is broken
# yet, but the next update would discard it.
printf '%s\n' "edited in place" >>"$doc_prefix/git/config"
case "$(run_doc "$repo/doctor.sh")" in
    *"was edited in place"*) ;;
    *) fail "doctor did not report an edit made to the installed copy" ;;
esac
[ "$(doc_status)" -eq 0 ] || fail "doctor treated a local edit as a failure"

# Read-only: the edit must survive being diagnosed.
grep -Fq "edited in place" "$doc_prefix/git/config" ||
    fail "doctor modified the installed copy"

# --- doctor checks routing, not just that configuration parses ---------------

# A parsing check passes while identity routing is broken, which is the failure
# that reaches other people: commits authored under the wrong address, or a
# connection made as the wrong user.
rt_home="$test_root/routing-home"
rt_state="$test_root/routing-state"
rt_overlay="$test_root/routing-overlay"
rt_work="$test_root/routing-work"
mkdir -p "$rt_home" "$rt_overlay/config/git" "$rt_overlay/config/ssh" "$rt_work/project"
git -C "$rt_work/project" init -q

# Git matches gitdir: against the resolved path. On macOS mktemp hands back a
# path under /var, which is a symlink to /private/var, so the condition would
# never match the repository it names.
rt_work_real="$(cd "$rt_work" && pwd -P)"

write_overlay() {
    # $1 selects whether the specific Host block precedes the wildcard.
    if [ "$1" = "shadowed" ]; then
        printf 'Host *.example.com\n    User generic\nHost build.example.com\n    User specific\n'
    else
        printf 'Host build.example.com\n    User specific\nHost *.example.com\n    User generic\n'
    fi >"$rt_overlay/config/ssh/config"

    cat >"$rt_overlay/config/git/config" <<CONF
[user]
	name = Example
[includeIf "gitdir:$rt_work_real/"]
	path = $rt_home/.local/share/dotfiles-private/git/${2:-work}
CONF
    printf '[user]\n\temail = work@example.com\n' >"$rt_overlay/config/git/work"
}

run_rt() {
    HOME="$rt_home" XDG_STATE_HOME="$rt_state" DOTFILES_PRIVATE_ROOT="$rt_overlay" \
        "$@" 2>&1 || true
}

rt_status() {
    HOME="$rt_home" XDG_STATE_HOME="$rt_state" DOTFILES_PRIVATE_ROOT="$rt_overlay" \
        "$repo/doctor.sh" >/dev/null 2>&1
    echo "$?"
}

write_overlay ordered
run_rt "$repo/install.sh" --all >/dev/null

# Report what doctor actually said, so a failure here is diagnosable from a CI
# log instead of needing a local reproduction on the same platform.
rt_output="$(run_rt "$repo/doctor.sh")"
case "$rt_output" in
    *"selects work@example.com"*) ;;
    *) fail "doctor did not verify a gitdir condition. Output:
$rt_output
condition: gitdir:$rt_work_real/  repo: $rt_work/project
origins: $(HOME="$rt_home" git -C "$rt_work/project" config --list --show-origin 2>&1 |
    grep -E "user\.|include" | tr '\n' ' ')" ;;
esac
case "$rt_output" in
    *"build.example.com resolves to specific"*) ;;
    *) fail "doctor did not verify a Host block. Output:
$rt_output
ssh -G said: $(HOME="$rt_home" ssh -G build.example.com 2>&1 | head -2 | tr '\n' ' ')
~/.ssh/config: $(ls -l "$rt_home/.ssh/config" 2>&1)
contents: $(cat "$rt_home/.ssh/config" 2>&1 | tr '\n' ' ')
include target: $(ls -l "$rt_home/.local/share/dotfiles-private/ssh/config" 2>&1)" ;;
esac
[ "$(rt_status)" -eq 0 ] || fail "doctor failed on correct routing"

# A specific Host after a wildcard is ignored by SSH, and the file still parses.
write_overlay shadowed
run_rt "$repo/update.sh" >/dev/null
case "$(run_rt "$repo/doctor.sh")" in
    *"declares user specific but resolves generic"*) ;;
    *) fail "doctor did not catch a Host block shadowed by a wildcard" ;;
esac
[ "$(rt_status)" -ne 0 ] || fail "shadowed routing did not fail the exit status"

# An include target that no longer exists, which is what a rename produces.
write_overlay ordered renamed
run_rt "$repo/update.sh" >/dev/null
case "$(run_rt "$repo/doctor.sh")" in
    *"which is missing"*) ;;
    *) fail "doctor did not report an include target that does not exist" ;;
esac

# Nothing to test against is reported as skipped rather than guessed at.
write_overlay ordered
sed -i.bak "s|gitdir:$rt_work_real/|gitdir:$test_root/routing-absent/|" \
    "$rt_overlay/config/git/config"
rm -f "$rt_overlay/config/git/config.bak"
run_rt "$repo/update.sh" >/dev/null
case "$(run_rt "$repo/doctor.sh")" in
    *"has no repository to test against"*) ;;
    *) fail "doctor did not skip a gitdir condition it could not evaluate" ;;
esac
[ "$(rt_status)" -eq 0 ] || fail "a skipped check was treated as a failure"

# --- a private checkout with no payload is reported, not skipped -------------

# An overlay that exists but has nothing to publish used to be indistinguishable
# from one that does not exist. Only the second is normal.
warn_home="$test_root/warn-home"
warn_state="$test_root/warn-state"
old_layout="$test_root/overlay-old-layout"
empty_layout="$test_root/overlay-empty"
mkdir -p "$warn_home" "$old_layout/git" "$empty_layout/config"
printf '[user]\n\tname = Example\n' >"$old_layout/git/config"

run_warn() {
    HOME="$warn_home" XDG_STATE_HOME="$warn_state" DOTFILES_PRIVATE_ROOT="$1" \
        "$repo/install.sh" git 2>&1 || true
}

case "$(run_warn "$old_layout")" in
    *"has no config/ directory"*) ;;
    *) fail "an overlay in the pre-config layout was skipped without warning" ;;
esac

case "$(run_warn "$empty_layout")" in
    *"is empty, so nothing will be published"*) ;;
    *) fail "an overlay with an empty config/ was skipped without warning" ;;
esac

# No overlay at all is the ordinary case and must stay quiet.
case "$(run_warn "$test_root/overlay-absent")" in
    *Warning*) fail "a missing overlay produced a warning" ;;
esac

# --- uninstall refuses targets it no longer owns -----------------------------

protected_home="$test_root/protected-home"
protected_state="$test_root/protected-state"
mkdir -p "$protected_home/.config/git"
printf '%s\n' "configuration to preserve" >"$protected_home/.config/git/config"

HOME="$protected_home" XDG_STATE_HOME="$protected_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/install.sh" git
unlink "$protected_home/.config/git"
mkdir -p "$protected_home/.config/git"
printf '%s\n' "replacement configuration" >"$protected_home/.config/git/config"

if HOME="$protected_home" XDG_STATE_HOME="$protected_state" \
    DOTFILES_PRIVATE_ROOT="$no_private" "$repo/uninstall.sh" git; then
    fail "uninstall accepted a target no longer owned by this clone"
fi
grep -Fqx "replacement configuration" "$protected_home/.config/git/config" ||
    fail "uninstall changed the replacement configuration"
grep -Fqx "configuration to preserve" \
    "$protected_state/dotfiles-installer/backups/.config/git/config" ||
    fail "uninstall removed the preserved configuration"

echo "Installer lifecycle tests passed."
