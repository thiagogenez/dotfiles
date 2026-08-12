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
[ ! -d "$fresh_state/dotfiles-installer" ] || fail "fresh install state was not removed"

# Update on an empty installation is a no-op, not an error.
HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" DOTFILES_PRIVATE_ROOT="$no_private" \
    "$repo/update.sh" >/dev/null || fail "update failed with nothing installed"

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
