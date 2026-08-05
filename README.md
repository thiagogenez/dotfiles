# dotfiles

Reusable Git and SSH configuration with optional support for a private local overlay.

## Contents

- [Layout](#layout)
- [Install](#install)
- [Private overlay](#private-overlay)
- [Uninstall](#uninstall)
- [Safety](#safety)

## Layout

```text
git/config     \
git/ignore      > ~/.config/git -> <clone>/git
ssh/config     -> ~/.ssh/config
install.sh        creates the two symlinks above
uninstall.sh      removes them and restores prior configuration
```

Git discovers `~/.config/git/config` and `~/.config/git/ignore` natively. Both Git
and SSH can load additional machine-specific configuration from the optional private
overlay.

## Install

On a new machine:

```bash
git clone https://github.com/thiagogenez/dotfiles.git "$HOME/.dotfiles" && "$HOME/.dotfiles/install.sh"
```

From an existing clone:

```bash
./install.sh
```

Re-running is safe. Existing files, directories, or symlinks are preserved under
`~/.local/state/dotfiles-installer/backups/` before installation. `git config
--global` writes through the XDG symlink to `git/config`, so edits made with Git itself
land in version control.

## Private overlay

Optional machine-specific configuration can be placed at:

```text
~/.dotfiles-private/
├── git/
│   └── config
└── ssh/
    └── config
```

The public Git and SSH files include these paths when they exist. Without the overlay,
common settings continue to work, but no Git identity is supplied.
`user.useConfigOnly = true` prevents commits with an inferred email address.

See [Create a private overlay](docs/private-overlay.md) for a complete example using
your own private repository, identities, signing configuration, and SSH defaults.

## Uninstall

From anywhere:

```bash
"$HOME/.dotfiles/uninstall.sh"
```

From inside the clone:

```bash
./uninstall.sh
```

Uninstall removes only `~/.config/git` and `~/.ssh/config` symlinks that point into
this clone, then restores whatever occupied those paths before installation. Files or
links placed there by something else after installation are left untouched, and the
preserved backups remain available for manual recovery. The clone is never deleted.

## Safety

No private key material, credentials, identity values, or host-specific defaults are
stored in this repository. Keep secrets in a dedicated credential manager or local
keyring, never in Git.
