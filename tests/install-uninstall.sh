#!/usr/bin/env bash

set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")"

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
        fail "$target does not point to $expected"
}

assert_absent() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        fail "$target still exists"
    fi
}

trap cleanup EXIT

fresh_home="$test_root/fresh-home"
fresh_state="$test_root/fresh-state"
mkdir -p "$fresh_home"

HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" "$repo/install.sh" --all
assert_link "$fresh_home/.config/git" "$repo/git"
assert_link "$fresh_home/.ssh/config" "$repo/ssh/config"
assert_absent "$fresh_home/.gnupg/gpg-agent.conf"

# A second installation must leave links intact without creating another backup.
HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" "$repo/install.sh" --all
assert_link "$fresh_home/.config/git" "$repo/git"
assert_link "$fresh_home/.ssh/config" "$repo/ssh/config"

HOME="$fresh_home" XDG_STATE_HOME="$fresh_state" "$repo/uninstall.sh" --all
assert_absent "$fresh_home/.config/git"
assert_absent "$fresh_home/.ssh/config"
[ ! -d "$fresh_state/dotfiles-installer" ] || fail "fresh install state was not removed"

existing_home="$test_root/existing-home"
existing_state="$test_root/existing-state"
mkdir -p "$existing_home/.config/git" "$existing_home/.ssh"
printf '%s\n' "original Git configuration" >"$existing_home/.config/git/config"
printf '%s\n' "original ignore rules" >"$existing_home/.config/git/ignore"
printf '%s\n' "original SSH configuration" >"$existing_home/.ssh/config"

HOME="$existing_home" XDG_STATE_HOME="$existing_state" "$repo/install.sh" git ssh
assert_link "$existing_home/.config/git" "$repo/git"
assert_link "$existing_home/.ssh/config" "$repo/ssh/config"

grep -Fqx "original Git configuration" \
    "$existing_state/dotfiles-installer/backups/.config/git/config" ||
    fail "Git configuration was not preserved"
grep -Fqx "original ignore rules" \
    "$existing_state/dotfiles-installer/backups/.config/git/ignore" ||
    fail "Git ignore rules were not preserved"
grep -Fqx "original SSH configuration" \
    "$existing_state/dotfiles-installer/backups/.ssh/config" ||
    fail "SSH configuration was not preserved"

HOME="$existing_home" XDG_STATE_HOME="$existing_state" "$repo/uninstall.sh" --all
[ ! -L "$existing_home/.config/git" ] || fail "restored Git configuration is still a link"
[ ! -L "$existing_home/.ssh/config" ] || fail "restored SSH configuration is still a link"
grep -Fqx "original Git configuration" "$existing_home/.config/git/config" ||
    fail "Git configuration was not restored"
grep -Fqx "original ignore rules" "$existing_home/.config/git/ignore" ||
    fail "Git ignore rules were not restored"
grep -Fqx "original SSH configuration" "$existing_home/.ssh/config" ||
    fail "SSH configuration was not restored"
[ ! -d "$existing_state/dotfiles-installer" ] || fail "restore state was not removed"

private_home="$test_root/private-home"
private_state="$test_root/private-state"
private_root="$test_root/private-overlay"
mkdir -p "$private_home" "$private_root/gnupg"
printf '%s\n' "pinentry-program /example/pinentry" >"$private_root/gnupg/gpg-agent.conf"

HOME="$private_home" XDG_STATE_HOME="$private_state" DOTFILES_PRIVATE_ROOT="$private_root" \
    "$repo/install.sh" gnupg
assert_link "$private_home/.gnupg/gpg-agent.conf" "$private_root/gnupg/gpg-agent.conf"
HOME="$private_home" XDG_STATE_HOME="$private_state" DOTFILES_PRIVATE_ROOT="$private_root" \
    "$repo/uninstall.sh" gnupg
assert_absent "$private_home/.gnupg/gpg-agent.conf"

protected_home="$test_root/protected-home"
protected_state="$test_root/protected-state"
mkdir -p "$protected_home/.config/git"
printf '%s\n' "configuration to preserve" >"$protected_home/.config/git/config"

HOME="$protected_home" XDG_STATE_HOME="$protected_state" "$repo/install.sh" git
unlink "$protected_home/.config/git"
mkdir -p "$protected_home/.config/git"
printf '%s\n' "replacement configuration" >"$protected_home/.config/git/config"

if HOME="$protected_home" XDG_STATE_HOME="$protected_state" "$repo/uninstall.sh" git; then
    fail "uninstall accepted a target no longer owned by this clone"
fi
grep -Fqx "replacement configuration" "$protected_home/.config/git/config" ||
    fail "uninstall changed the replacement configuration"
grep -Fqx "configuration to preserve" \
    "$protected_state/dotfiles-installer/backups/.config/git/config" ||
    fail "uninstall removed the preserved configuration"

echo "Installer lifecycle tests passed."
