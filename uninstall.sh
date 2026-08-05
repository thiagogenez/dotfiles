#!/usr/bin/env bash
#
# Removes symlinks installed by install.sh and restores the targets that were
# present before installation. Files and links owned elsewhere are untouched.

set -euo pipefail

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

cd "$(dirname "$0")"
repo="$PWD"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-installer"
backup_root="$state_root/backups"
failed=0

uninstall_link() {
    local src="$repo/$1" dst="$HOME/$2" backup="$backup_root/$2"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        unlink "$dst"
        echo "removed $dst"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
        echo "skipped $dst (not owned by this clone)" >&2
        return 1
    fi

    if [ -e "$backup" ] || [ -L "$backup" ]; then
        mkdir -p "$(dirname "$dst")"
        mv "$backup" "$dst"
        echo "restored $dst"
    fi
}

if ! uninstall_link git .config/git; then
    failed=1
fi
if ! uninstall_link ssh/config .ssh/config; then
    failed=1
fi

if [ "$failed" -ne 0 ]; then
    echo >&2
    echo "Uninstall incomplete; preserved backups remain in $backup_root" >&2
    exit 1
fi

if [ -e "$state_root/installed" ]; then
    unlink "$state_root/installed"
fi
rmdir "$backup_root/.config" 2>/dev/null || true
rmdir "$backup_root/.ssh" 2>/dev/null || true
rmdir "$backup_root" 2>/dev/null || true
rmdir "$state_root" 2>/dev/null || true

echo
echo "Done. The pre-install configuration has been restored."
