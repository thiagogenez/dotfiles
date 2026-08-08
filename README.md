# dotfiles

[![CI](https://github.com/thiagogenez/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/thiagogenez/dotfiles/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Reusable Git, SSH, and GnuPG configuration with optional support for a private
local overlay.

## Contents

- [Layout](#layout)
- [Install](#install)
- [Private overlay](#private-overlay)
- [Uninstall](#uninstall)
- [Development](#development)
- [Safety](#safety)
- [License](#license)

## Layout

```text
git/config     \
git/ignore      > ~/.config/git -> <clone>/git
ssh/config     -> ~/.ssh/config
gnupg/            documents the optional private GnuPG component
install.sh        interactively installs selected components
uninstall.sh      removes selected components and restores prior configuration
```

Git discovers `~/.config/git/config` and `~/.config/git/ignore` natively. Both Git
and SSH can load additional machine-specific configuration from the optional private
overlay.

This project uses Git's [XDG configuration location](https://git-scm.com/docs/git-config)
instead of the traditional `~/.gitconfig`. XDG keeps user configuration under
`$XDG_CONFIG_HOME`, which defaults to `~/.config`; see the
[XDG Base Directory Specification](https://specifications.freedesktop.org/basedir/)
for the convention and its other standard directories.

## Install

On a new machine:

```bash
git clone https://github.com/thiagogenez/dotfiles.git "$HOME/.dotfiles" && "$HOME/.dotfiles/install.sh"
```

From an existing clone, launch the interactive selector:

```bash
./install.sh
```

Use the keyboard to select Git, SSH, and—when its private configuration
exists—GnuPG. For scripts or unattended setup, name components explicitly or
install everything available:

```bash
./install.sh git ssh
./install.sh --all
```

Re-running is safe. Existing files, directories, or symlinks are preserved under
`~/.local/state/dotfiles-installer/backups/` before installation. `git config
--global` writes through the XDG symlink to `git/config`, so edits made with Git
itself land in version control.

## Private overlay

Optional machine-specific configuration can be placed at:

```text
~/.dotfiles-private/
├── git/
│   └── config
├── gnupg/
│   └── gpg-agent.conf
└── ssh/
    └── config
```

The public Git and SSH files include these paths when they exist. Without the overlay,
common settings continue to work, but no Git identity is supplied. Because
`gpg-agent.conf` has no config-include directive, the optional GnuPG component
links that private file directly instead of passing through a public file.
`user.useConfigOnly = true` prevents commits with an inferred email address.

The installer only manages the GnuPG configuration link. It does not install
GnuPG, pinentry software, private keys, or Keychain credentials.

See [Create a private overlay](docs/private-overlay.md) for a complete example using
your own private repository, identities, signing configuration, and SSH defaults.

## Uninstall

From anywhere, select which installed components to remove:

```bash
"$HOME/.dotfiles/uninstall.sh"
```

From inside the clone:

```bash
./uninstall.sh
```

For unattended removal:

```bash
./uninstall.sh --all
```

Uninstall removes only selected symlinks that still point to the source managed
by this clone or its private overlay, then restores whatever occupied those paths
before installation. Files or links placed there by something else after
installation are left untouched, and preserved backups remain available for
manual recovery. The clone is never deleted.

## Development

Run the local checks with:

```bash
shellcheck -x install.sh uninstall.sh lib/dotfiles.sh tests/*.sh
bash tests/install-uninstall.sh
```

GitHub Actions runs ShellCheck, Markdownlint, and the complete install/uninstall
lifecycle on Ubuntu and macOS. The lifecycle test uses isolated temporary home and
state directories; it never modifies the runner's real user configuration.

## Safety

No private key material, credentials, identity values, or host-specific defaults
are stored in this repository. Keep secrets in a dedicated credential manager or
local keyring, never in Git.

## License

Released under the [MIT License](LICENSE).
