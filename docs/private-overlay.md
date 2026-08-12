# Create a private overlay

The public dotfiles intentionally contain no Git identity or machine-specific SSH
defaults. An optional private repository can provide those values without exposing
them in a public commit.

## 1. Create and clone a private repository

Create a private repository in your own GitHub account, then clone it beside the
public checkout, which is where the installer looks for it by default:

```bash
public="$(cd "$(dirname "$0")" && pwd)"   # or the path you cloned dotfiles into
gh repo create YOUR_GITHUB_USER/dotfiles-private --private
gh repo clone YOUR_GITHUB_USER/dotfiles-private "$(dirname "$public")/dotfiles-private"
```

Set `DOTFILES_PRIVATE_ROOT` if you keep it elsewhere.

Everything the installer publishes lives under `config/`, matching the public
repository:

```text
dotfiles-private/
└── config/
    ├── git/
    ├── gnupg/
    └── ssh/
```

Anything outside `config/` is yours to use for notes or scripts and is never
published.

Two paths matter throughout this document and they are not the same:

- The **checkout**, where you create and commit these files.
- `~/.local/share/dotfiles-private`, the copy `install.sh` publishes and the only
  path that belongs inside an include directive.

Never point an include at the checkout. Publishing exists so that nothing under
`$HOME` depends on where the checkout lives.

## 2. Add private Git routing

Create `config/git/config` in the private checkout:

```gitconfig
[user]
    name = Your Name

[includeIf "hasconfig:remote.*.url:git@github.com:YOUR_GITHUB_USER/**"]
    path = ~/.local/share/dotfiles-private/git/personal
[includeIf "hasconfig:remote.*.url:https://github.com/YOUR_GITHUB_USER/**"]
    path = ~/.local/share/dotfiles-private/git/personal
[includeIf "gitdir:~/work/"]
    path = ~/.local/share/dotfiles-private/git/work
```

Adjust the remote and directory patterns to match your repositories. Git silently
ignores include conditions that do not match.

A `gitdir` condition matches where a repository lives on disk, so it keeps naming
your working directories. Only `path` values move to the published location.

## 3. Add identities and signing

For SSH signing, create `config/git/personal` in the private checkout:

```gitconfig
[user]
    email = YOUR_EMAIL
    signingkey = ~/.ssh/id_ed25519.pub
[gpg]
    format = ssh
```

For OpenPGP signing, create `config/git/work` in the private checkout:

```gitconfig
[user]
    email = YOUR_WORK_EMAIL
    signingkey = YOUR_OPENPGP_KEY_ID
[gpg]
    format = openpgp
```

The public configuration enables signed commits. If you do not want signing, override
it in the private `config/git/config`:

```gitconfig
[commit]
    gpgsign = false
```

Never store private keys, tokens, passwords, or recovery material in either
repository. A signing key path should point to a public key; the private key should
remain in an SSH agent, credential manager, or local keyring.

## 4. Add optional SSH defaults

Create `config/ssh/config` in the private checkout only when private host or user
are needed:

```sshconfig
Host *.example.com
    User your-user
```

The public SSH configuration includes the published copy automatically when it
exists. Order matters: a more specific `Host` block must come before a broader one,
because SSH keeps the first value it finds for each keyword.

## 5. Add optional GnuPG agent configuration

GnuPG does not support an SSH-style include in `gpg-agent.conf`. To manage it
through the private overlay, create `config/gnupg/gpg-agent.conf` in the private
checkout with the agent options needed on your machine. For example:

```text
pinentry-program /absolute/path/to/your/pinentry
```

Then run `./install.sh` and select GnuPG. The installer publishes the file and links
`~/.gnupg/gpg-agent.conf` at the published copy; it does not install GnuPG, pinentry,
private keys, or credentials. `./update.sh` restarts the agent when this file changes.

This is the one component whose link names a private file directly. Every other
one reaches its file through an include in a public configuration file, which
`gpg-agent.conf` has no directive for.

## 6. Add optional private ignore rules

Create `config/git/ignore` in the private checkout for patterns that should not
appear in the public repository, then select it from the private
`config/git/config`:

```gitconfig
[core]
    excludesfile = ~/.local/share/dotfiles-private/git/ignore
```

## 7. Publish and save the private overlay

Publish the overlay so the include paths resolve:

```bash
./update.sh          # or ./install.sh on first setup
git config --list --show-origin | grep dotfiles-private
```

Commit and push the overlay only after confirming that its GitHub repository is
private:

```bash
cd /path/to/dotfiles-private
gh repo view --json visibility
git add .
git commit -S -m "Add private dotfiles overlay"
git push -u origin main
```

Remember that editing the checkout has no effect until `./update.sh`
republishes it.

The public `uninstall.sh` removes the symlinks it installed and the copies it
published. It never deletes either checkout.
