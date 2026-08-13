# dotfiles

[![CI](https://github.com/thiagogenez/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/thiagogenez/dotfiles/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Reusable Git, SSH, and GnuPG configuration with optional support for a private
local overlay.

## Contents

- [Layout](#layout)
- [Install](#install)
- [Update](#update)
- [Doctor](#doctor)
- [Private overlay](#private-overlay)
- [Uninstall](#uninstall)
- [Development](#development)
- [Safety](#safety)
- [License](#license)

## Layout

```text
config/           everything here is published, nothing else is
  git/config   \
  git/ignore    > ~/.local/share/dotfiles/git <- ~/.config/git
  ssh/config   -> ~/.local/share/dotfiles/ssh/config <- ~/.ssh/config
lib/              the installer itself
install.sh        publishes the checkout and links selected components
update.sh         republishes the checkout after editing it
doctor.sh         reports whether this machine's installation is healthy
uninstall.sh      removes selected components and restores prior configuration
```

Installation has three layers. The checkout is where configuration is authored
and version-controlled. `install.sh` copies its payload to
`~/.local/share/dotfiles`, and `$HOME` is linked at that copy. Nothing under
`$HOME` resolves back into the checkout, so the checkout can live anywhere,
including a directory the operating system gates behind a privacy prompt.

| Layer | Path | Role |
| --- | --- | --- |
| Source | wherever you cloned it | edit here, commit here |
| Installed | `~/.local/share/dotfiles` | published copy, do not edit |
| Active | `~/.config/git`, `~/.ssh/config` | links into the installed copy |

The tradeoff is that edits to the checkout are inert until published. Run
[`./update.sh`](#update) after changing a configuration file.

Git discovers `~/.config/git/config` and `~/.config/git/ignore` natively. Both
Git and SSH can load additional machine-specific configuration from the optional
private overlay.

This project uses Git's
[XDG configuration location](https://git-scm.com/docs/git-config) instead of the
traditional `~/.gitconfig`. XDG keeps user configuration under
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
`~/.local/state/dotfiles-installer/backups/` before installation. Links created
by earlier versions of this installer, which pointed directly at the checkout,
are adopted rather than preserved.

## Update

Editing a file in the checkout does not change the active configuration until
the installed copy is republished:

```bash
./update.sh
```

Only installed components are considered. Files that changed are copied, files
deleted from the checkout are pruned from the installed copy, and any link that
has gone missing is restored. A run that finds nothing to do prints one line and
changes nothing.

To see what is stale without writing anything:

```bash
./update.sh --check
```

`--check` exits non-zero when the installed copy has drifted, so it can gate a
prompt or a scheduled job.

Because `git config --global` writes through the XDG symlink, it edits the
*installed* copy rather than the checkout. The installer records what it
published, so it can tell that kind of edit from a stale checkout: `update.sh`
copies it into `~/.local/state/dotfiles-installer/backups/local/` before
replacing it, and says so. Move anything worth keeping into the checkout, where
it is version-controlled.

## Doctor

To check whether this machine's installation is healthy:

```bash
./doctor.sh
```

It reports the payload each checkout publishes, where every component link
points, whether anything under `$HOME` resolves back into a checkout, whether
the installed copy carries edits the next update would replace, and whether Git
and SSH resolve their configuration.

Read-only. It never repairs anything, so it is safe to run when something
already looks wrong. It exits non-zero on a failure, so it can gate a shell
prompt or a scheduled job. `./update.sh` is what repairs links and republishes.

## Private overlay

Optional machine-specific configuration lives in a second checkout, by default a
`dotfiles-private` directory beside this one:

```text
dotfiles-private/
└── config/
    ├── git/
    │   └── config
    ├── gnupg/
    │   └── gpg-agent.conf
    └── ssh/
        └── config
```

Set `DOTFILES_PRIVATE_ROOT` to keep it somewhere else. It is published alongside
the public payload to `~/.local/share/dotfiles-private`, and the public Git and
SSH files include it from there. Without the overlay, common settings continue
to work, but no Git identity is supplied. Because `gpg-agent.conf` has no
config-include directive, the optional GnuPG component links that published file
directly instead of passing through a public file. `user.useConfigOnly = true`
prevents commits with an inferred email address.

Git's `include.path` and SSH's `Include` do not expand environment variables, so
those directives hard-code `~/.local/share/dotfiles-private`. Setting
`XDG_DATA_HOME` elsewhere moves the published copy out from under them; the
installer warns when it detects this.

The installer only manages the GnuPG configuration link. It does not install
GnuPG, pinentry software, private keys, or Keychain credentials.

See [Create a private overlay](docs/private-overlay.md) for a complete example
using your own private repository, identities, signing configuration, and SSH
defaults.

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

Uninstall removes only selected symlinks that still point into the installed
copy, then restores whatever occupied those paths before installation. Files or
links placed there by something else after installation are left untouched, and
preserved backups remain available for manual recovery. Once no components
remain installed, the published copies under `~/.local/share` are removed too.
Neither checkout is ever deleted.

## Development

Run the local checks with:

```bash
shellcheck -x ./*.sh lib/*.sh tests/*.sh
shfmt -d -i 4 -ci -kp ./*.sh lib/*.sh tests/*.sh
bash tests/install-uninstall.sh
bash tests/architecture.sh
bash tests/commit-message.sh
```

GitHub Actions runs ShellCheck, shfmt, Markdownlint, secret scanning, commit
message validation, and the complete install/uninstall lifecycle on Ubuntu and
macOS. The lifecycle and architecture tests use isolated temporary home and
state directories; they never modify the runner's real user configuration.

These are contributor and CI tools. Running the installer itself needs bash and
git and nothing else. See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow
and [AGENTS.md](AGENTS.md) for the rules coding agents follow here.

## Safety

No private key material, credentials, identity values, or host-specific defaults
are stored in this repository. Keep secrets in a dedicated credential manager or
local keyring, never in Git.

## License

Released under the [MIT License](LICENSE).
