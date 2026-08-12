#!/usr/bin/env bash

# Assert the boundary the whole design rests on:
#
#   Nothing under $HOME may resolve into a source checkout, and every component
#   link must resolve inside the install prefix.
#
# This is what lets a checkout live in a directory the operating system gates
# behind a consent prompt. Breaking it is quiet: a component linked to the
# checkout still passes every functional test and only fails for callers that
# lack access to that directory. Kept separate from the lifecycle suite so the
# rule has a name of its own.

set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-arch.XXXXXX")"

overlay="$test_root/private-checkout"
home="$test_root/home"
state="$test_root/state"
prefix="$home/.local/share/dotfiles"
private_prefix="$home/.local/share/dotfiles-private"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

cleanup() {
    case "$(basename "$test_root")" in
        dotfiles-arch.*) rm -rf -- "$test_root" ;;
        *) fail "refusing to remove unexpected test path: $test_root" ;;
    esac
}

trap cleanup EXIT

run() {
    HOME="$home" XDG_STATE_HOME="$state" DOTFILES_PRIVATE_ROOT="$overlay" "$@"
}

# No link anywhere under $HOME may point into either checkout.
assert_no_link_into_source() {
    local phase="$1" link target
    while IFS= read -r link; do
        [ -n "$link" ] || continue
        target="$(readlink "$link")"
        case "$target" in
            "$repo" | "$repo"/* | "$overlay" | "$overlay"/*)
                fail "after $phase: $link resolves into a checkout at $target"
                ;;
        esac
    done <<EOF
$(find "$home" -type l 2>/dev/null)
EOF
}

# The converse: each installed component must land inside a prefix.
assert_links_target_prefix() {
    local phase="$1" link target found=0
    for link in "$home/.config/git" "$home/.ssh/config" "$home/.gnupg/gpg-agent.conf"; do
        [ -L "$link" ] || continue
        found=$((found + 1))
        target="$(readlink "$link")"
        case "$target" in
            "$prefix"/* | "$private_prefix"/*) ;;
            *) fail "after $phase: $link targets $target, outside the install prefix" ;;
        esac
    done
    [ "$found" -eq 3 ] || fail "after $phase: expected 3 component links, found $found"
}

check() {
    assert_no_link_into_source "$1"
    assert_links_target_prefix "$1"
}

mkdir -p "$home" "$overlay/config/gnupg" "$overlay/config/git" "$overlay/config/ssh"
printf '%s\n' "pinentry-program /example/pinentry" >"$overlay/config/gnupg/gpg-agent.conf"
printf '[user]\n\tname = Example\n' >"$overlay/config/git/config"
printf 'Host example\n    User example\n' >"$overlay/config/ssh/config"

run "$repo/install.sh" --all >/dev/null
check "install"

run "$repo/update.sh" >/dev/null
check "update"

# A link deliberately pointed back at the checkout must be repaired, not kept.
rm "$home/.ssh/config"
ln -s "$repo/config/ssh/config" "$home/.ssh/config"
run "$repo/update.sh" >/dev/null
check "update over a link into the checkout"

# Reinstalling over the previous scheme must not leave a checkout link behind.
rm "$home/.config/git"
ln -s "$repo/config/git" "$home/.config/git"
run "$repo/install.sh" --all >/dev/null
check "reinstall over a link into the checkout"

echo "Architecture invariant holds."
