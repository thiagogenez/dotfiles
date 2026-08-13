# Contributing

Thanks for taking a look. This is a small repository with a narrow purpose, so
the process is short.

If you are a coding agent, read [AGENTS.md](AGENTS.md) instead. It covers the
same ground with the detail an agent needs.

## Contents

- [Workflow](#workflow)
- [What belongs here](#what-belongs-here)
- [Running the checks](#running-the-checks)
- [The rule that carries the design](#the-rule-that-carries-the-design)
- [Pull requests](#pull-requests)
- [Secrets](#secrets)

## Workflow

Every change starts from an issue, so the reasoning is recorded somewhere other
than a commit message. Pick the template that matches what you are proposing:

| Template | Use it for |
| --- | --- |
| Fix | something behaves incorrectly |
| Enhancement | existing behaviour could be better |
| Feature | a capability that does not exist yet |

Then branch from `main`, open a pull request referencing the issue, and merge
after review and passing checks. `main` is not committed to directly.

## What belongs here

A Bash installer for Git, SSH, and GnuPG configuration, plus an optional private
overlay for identities and host defaults. There is no service, runtime, or
frontend.

That rules out a fair amount of otherwise reasonable tooling. Runtime
observability has no process to instrument, since `install.sh` runs once and
exits. JavaScript linters and browser test runners have nothing to act on. If
you are proposing a tool, say what it operates on in a repository made of shell
scripts and configuration files.

Target Bash 3.2, which is what macOS ships. Associative arrays, `mapfile`, and
`${var^^}` are not available.

## Running the checks

```bash
shellcheck -x install.sh update.sh uninstall.sh doctor.sh lib/dotfiles.sh tests/*.sh
shfmt -d -i 4 -ci -kp install.sh update.sh uninstall.sh doctor.sh lib/dotfiles.sh tests/*.sh
bash tests/install-uninstall.sh
bash tests/architecture.sh
bash tests/commit-message.sh
```

`./doctor.sh` reports whether the current machine's installation is healthy. It
is read-only and never repairs; `./update.sh` does that.

None of this is required to contribute. CI runs the same commands, so skipping
them locally costs you a round trip and nothing else. If you do want them,
`brew install shellcheck shfmt` covers the two that are not already on your
machine; both are single binaries with no dependency tree.

`shellcheck` covers correctness and `shfmt` covers layout, so they do not
overlap. These are contributor and CI tools only. Running the installer needs
bash and git, nothing more, and that must stay true.

## Optional tooling

Two conventions here are easier to follow with help. Commit messages take a
terse Conventional Commits form, and issue and pull request text should read as
written rather than generated. If you use a coding agent, these produce both:

```bash
npx skills add JuliusBrussee/caveman -a <agent>   # commit messages
npx skills add blader/humanizer -a <agent>        # issue and pull request prose
```

`<agent>` is `claude`, `codex`, `cursor`, and so on.

Both install third-party code from GitHub, so read what you are installing.
Neither is expected of you. The conventions are written out in this file and in
[AGENTS.md](AGENTS.md), and work written by hand is judged the same way.

The lifecycle test builds temporary home and state directories and never touches
your real configuration. It also points `DOTFILES_PRIVATE_ROOT` at a path that
does not exist, so a private overlay sitting next to the checkout cannot leak
into the fixtures. Please keep that property when adding tests.

`tests/architecture.sh` asserts the boundary described below. `tests/commit-message.sh`
checks commit subjects, and accepts a range or `--text "subject"` for a single one.

Markdown files are checked with markdownlint, which limits lines to 80
characters. Issue and pull request bodies are not files and should not be
wrapped: GitHub renders a single newline in a comment as a line break, so
wrapped text arrives on the page as ragged short lines.

## The rule that carries the design

Nothing under `$HOME` may resolve into the source checkout. Links point at the
installed copy under `~/.local/share/dotfiles`, never at the repository.

This is what lets the checkout live anywhere, including a directory the
operating system gates behind a consent prompt such as `~/Documents` on macOS.
Breaking it is quiet: a component linked to the checkout still passes every
functional test and only fails for callers without access to that directory.
The test suite asserts the rule directly, and that assertion should not be
weakened to make a change pass.

## Pull requests

Write the title as a Conventional Commit; a squash merge takes it as the
subject, so CI checks the title under the same rules as the commits. Keep the
subject at 50 characters where you can, 72 at the outside, lowercase after the
colon, with no trailing period. Add a body only when the diff does not explain
why, and always for breaking changes, security fixes, and reverts.

In the body of the pull request, cover the linked issue, what changed, how you
validated it, and any risks, limitations, or open questions.

On validation: name the commands and their results rather than writing "tests
pass". If you checked something by hand, describe what you looked at.

Commits on `main` are signed by the repository owner, so a maintainer may ask to
land your work through a squash merge.

## Secrets

No key material, credentials, identities, or host-specific values belong in this
repository. They go in the private overlay, which is a separate repository. A
signing key setting should name a public key or a key ID.

If a secret does reach the history, rotate it. Removing the commit is not enough
by itself.
