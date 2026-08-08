# Create a private overlay

The public dotfiles intentionally contain no Git identity or machine-specific SSH
defaults. An optional private repository can provide those values without exposing
them in a public commit.

## 1. Create and clone a private repository

Create a private repository in your own GitHub account, then clone it to the fixed
path used by the public configuration:

```bash
gh repo create YOUR_GITHUB_USER/dotfiles-private --private
gh repo clone YOUR_GITHUB_USER/dotfiles-private "$HOME/.dotfiles-private"
mkdir -p \
  "$HOME/.dotfiles-private/git" \
  "$HOME/.dotfiles-private/ssh" \
  "$HOME/.dotfiles-private/gnupg"
```

The repository name is only a suggestion. If you use another local path, update
the include paths in the public `git/config` and `ssh/config` files.

## 2. Add private Git routing

Create `~/.dotfiles-private/git/config`:

```gitconfig
[user]
    name = Your Name

[includeIf "hasconfig:remote.*.url:git@github.com:YOUR_GITHUB_USER/**"]
    path = ~/.dotfiles-private/git/personal
[includeIf "hasconfig:remote.*.url:https://github.com/YOUR_GITHUB_USER/**"]
    path = ~/.dotfiles-private/git/personal
[includeIf "gitdir:~/work/"]
    path = ~/.dotfiles-private/git/work
```

Adjust the remote and directory patterns to match your repositories. Git silently
ignores include conditions that do not match.

## 3. Add identities and signing

For SSH signing, create `~/.dotfiles-private/git/personal`:

```gitconfig
[user]
    email = YOUR_EMAIL
    signingkey = ~/.ssh/id_ed25519.pub
[gpg]
    format = ssh
```

For OpenPGP signing, create `~/.dotfiles-private/git/work`:

```gitconfig
[user]
    email = YOUR_WORK_EMAIL
    signingkey = YOUR_OPENPGP_KEY_ID
[gpg]
    format = openpgp
```

The public configuration enables signed commits. If you do not want signing, override
it in the private `git/config`:

```gitconfig
[commit]
    gpgsign = false
```

Never store private keys, tokens, passwords, or recovery material in either
repository. A signing key path should point to a public key; the private key should
remain in an SSH agent, credential manager, or local keyring.

## 4. Add optional SSH defaults

Create `~/.dotfiles-private/ssh/config` only when private host or user settings
are needed:

```sshconfig
Host *.example.com
    User your-user
```

The public SSH configuration includes this file automatically when it exists.

## 5. Add optional GnuPG agent configuration

GnuPG does not support an SSH-style include in `gpg-agent.conf`. To manage it
through the private overlay, create `~/.dotfiles-private/gnupg/gpg-agent.conf`
with the agent options needed on your machine. For example:

```text
pinentry-program /absolute/path/to/your/pinentry
```

Then run `./install.sh` and select GnuPG. The installer links the private file
directly to `~/.gnupg/gpg-agent.conf`; it does not install GnuPG, pinentry,
private keys, or credentials.

## 6. Add optional private ignore rules

Create `~/.dotfiles-private/git/ignore` for patterns that should not appear in the
public repository, then select it from the private `git/config`:

```gitconfig
[core]
    excludesfile = ~/.dotfiles-private/git/ignore
```

## 7. Save the private overlay

Commit and push the overlay only after confirming that its GitHub repository is
private:

```bash
cd "$HOME/.dotfiles-private"
gh repo view --json visibility
git add .
git commit -S -m "Add private dotfiles overlay"
git push -u origin main
```

The public `uninstall.sh` removes only the symlinks it installed. It never deletes
the private overlay repository.
