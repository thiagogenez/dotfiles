#!/usr/bin/env bash
#
# Installs this clone's Git and SSH configuration. Any pre-existing targets are
# preserved in a private state directory so uninstall.sh can restore them.

set -euo pipefail
umask 077

if [ "$#" -ne 0 ]; then
    echo "Usage: $0" >&2
    exit 2
fi

cd "$(dirname "$0")"
repo="$PWD"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-installer"
backup_root="$state_root/backups"

install_link() {
    local src="$repo/$1" dst="$HOME/$2" backup="$backup_root/$2"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "already linked $dst -> $src"
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ -e "$backup" ] || [ -L "$backup" ]; then
            echo "Cannot preserve $dst: backup already exists at $backup" >&2
            exit 1
        fi

        mkdir -p "$(dirname "$backup")"
        mv "$dst" "$backup"
        echo "preserved $dst at $backup"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "linked $dst -> $src"
}

mkdir -p "$state_root"
install_link git        .config/git
install_link ssh/config .ssh/config
touch "$state_root/installed"

echo
echo "Done. Inspect the active configuration with:"
echo "  git config --global --list --show-origin"
