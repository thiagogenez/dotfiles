# Security policy

## Supported version

The `main` branch. There are no releases to patch separately.

## What counts as a vulnerability here

This project is a Bash installer. It runs locally, under your own account, on
files you already own. There is no server, no network listener, and no
privilege boundary being crossed, so most reports will not be vulnerabilities
in the usual sense.

These would be:

- The installer writing outside the paths it declares, or following a symlink
  out of them.
- The published copy under `~/.local/share` or the backup store under
  `~/.local/state` being created with permissions that expose private material.
  The library sets `umask 077` for this reason.
- Any path by which the private overlay's contents could reach this public
  repository.
- Key material or credentials being logged, copied, or committed.

These would not:

- Choosing to put a secret in the public checkout. That is the failure the
  public and private split exists to prevent, and push protection and gitleaks
  both warn about it.
- Vulnerabilities in Git, SSH, GnuPG, or your package manager.

## Reporting

Use GitHub's private reporting: open the Security tab and choose "Report a
vulnerability". That reaches the maintainer without the report being public
first.

Please do not open a public issue for something that would expose a working
credential or a reproducible path to one.

Include what you ran, what happened, and what you expected. If a credential of
yours was exposed while finding it, rotate it; removing a commit does not undo
disclosure.

## What is already in place

- Secret scanning with push protection, which blocks a known provider's
  credential before the push lands.
- gitleaks over the full history on every push and pull request, plus a weekly
  scheduled run. It covers the generic and high-entropy patterns that GitHub's
  free tier does not.
- Dependabot alerts and updates for the GitHub Actions used in CI.
- Signed commits, and branch protection on `main` that applies to
  administrators as well.

No key material, credentials, identities, or host-specific values belong in
this repository. They live in a separate private overlay.
