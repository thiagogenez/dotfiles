# GnuPG configuration

`gpg-agent.conf` does not support an SSH-style include directive. The optional
GnuPG installer component therefore links `~/.gnupg/gpg-agent.conf` directly to:

```text
~/.dotfiles-private/gnupg/gpg-agent.conf
```

The component is offered only when that private file exists. The installer does
not install GnuPG, pinentry, private keys, or Keychain credentials.
