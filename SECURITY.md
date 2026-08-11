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

The distinction that matters is whether the tool caused it. If the installer
puts a secret somewhere it should not be, that is a bug and belongs here. If a
person commits a secret by hand, that is the failure the public and private
split exists to prevent, and push protection and the secret scan in CI already
warn about it.

Vulnerabilities in Git, SSH, GnuPG, or your package manager belong to those
projects.

## Reporting

Open the Security tab and choose "Report a vulnerability". That reaches the
maintainer privately, before anything becomes public. It needs a GitHub
account; there is no second channel, because publishing a contact address on a
repository this size collects more spam than reports.

Please do not open a public issue for anything that would expose a working
credential or a reproducible path to one.

Include what you ran, what happened, and what you expected.

## What to expect

This is maintained by one person, in spare time. So, honestly:

- A first reply within about a week. If two weeks pass with nothing, assume the
  notification was missed rather than ignored, and say so on the same private
  report.
- An assessment of whether it is in scope, with reasoning, even when the answer
  is no.
- A fix through the normal pull request flow, and a GitHub security advisory
  when a released behaviour changed.
- Credit in the advisory if you want it, and none if you would rather not.

There is no bounty. There is no embargo period being demanded of you either: if
a fix is taking unreasonably long, publishing is your call, and saying so first
is appreciated rather than resented.

## Safe harbour

Good-faith research on your own machine and your own copy of this repository is
welcome, and no action will be pursued over it. That covers reading the code,
running it against your own files, and reporting what you find.

It does not extend to other people's data, other people's machines, or the
private overlay of anyone but yourself.

## What is already in place

These are checks the repository runs, not guarantees:

- Secret scanning with push protection, which blocks a known provider's
  credential before a push lands. GitHub's free tier covers catalogued
  providers only.
- A gitleaks scan over the full history, defined in
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml), which covers the
  generic and high-entropy patterns the free tier does not.
- Dependabot alerts and updates for the GitHub Actions used in CI.
- Signed commits, and branch protection on `main` that applies to
  administrators as well.

The workflow file is the accurate record of what CI enforces. Repository
settings can be changed without this document noticing, so treat the list above
as a description of intent and the workflow as the source of truth.

No key material, credentials, identities, or host-specific values belong in
this repository. They live in a separate private overlay.
