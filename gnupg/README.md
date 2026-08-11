# GnuPG configuration

`gpg-agent.conf` does not support an SSH-style include directive. The optional
GnuPG installer component therefore links `~/.gnupg/gpg-agent.conf` straight at
the published copy of the private overlay:

```text
~/.local/share/dotfiles-private/gnupg/gpg-agent.conf
```

Every other component reaches its file through an include in a public
configuration file. This one cannot, so the link names the private file itself.

The component is offered only when that file exists in the private checkout. The
installer does not install GnuPG, pinentry, private keys, or Keychain
credentials.
