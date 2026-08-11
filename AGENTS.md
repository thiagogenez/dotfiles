# Working on this repository

These instructions apply to every contributor, human or agent. Read them before
changing anything.

This is the canonical file. Codex, Cursor, Devin, and Jules read `AGENTS.md`
natively, and Claude Code reads it as well. `CLAUDE.md` is a pointer to this
file rather than a copy, so the two cannot fall out of sync. If you add a file
for another agent, point it here too.

## Contents

- [What this project is](#what-this-project-is)
- [The rule that carries the design](#the-rule-that-carries-the-design)
- [Workflow](#workflow)
- [Pull requests](#pull-requests)
- [Commits](#commits)
- [Local checks](#local-checks)
- [Scope discipline](#scope-discipline)
- [Secrets](#secrets)

## What this project is

A Bash installer for Git, SSH, and GnuPG configuration, with an optional private
overlay holding identities and host defaults. There is no application, no
service, and no runtime. `install.sh` runs and exits.

That shapes what belongs here. Tooling aimed at long-running services or web
frontends has nothing to instrument in this repository. Before proposing an
addition, check that it has a target in a project made of shell scripts and
configuration files.

Installation has three layers:

| Layer | Path | Role |
| --- | --- | --- |
| Source | wherever the repository is cloned | edited and version-controlled |
| Installed | `~/.local/share/dotfiles` | published copy |
| Active | `~/.config/git`, `~/.ssh/config` | links into the installed copy |

## The rule that carries the design

> Nothing under `$HOME` may resolve into the source checkout.

Links point at the installed copy, never at the repository. This is what lets
the checkout live in a directory the operating system gates behind a consent
prompt, such as `~/Documents` on macOS, without breaking every process that
reads the configuration.

Breaking this rule is quiet. A component whose link target comes from the
checkout instead of the prefix still passes every functional test, and only
fails for callers that lack access to that directory.
`tests/install-uninstall.sh` asserts the invariant directly. Do not weaken that
assertion to make a change pass.

Git's `include.path` and SSH's `Include` do not expand environment variables, so
those directives hard-code `~/.local/share/dotfiles-private`. Changing the
prefix means changing those files too.

## Workflow

1. Every change starts from an issue. Open one if it does not exist.
2. Label it `fix` for a correction, `enhancement` for an improvement to existing
   behaviour, or `feature` for a new capability.
3. Branch from `main`. Name it after the type and the subject, for example
   `fix/prefix-permissions` or `feat/gitleaks`.
4. Open a pull request that references the issue.
5. Merge only after review and passing checks.

Never commit directly to `main`.

## Pull requests

Every pull request body must cover four things:

- **Issue.** Link it, and use `Closes #N` when the pull request resolves it.
- **What changed.** The substance, not a file list. A reviewer should understand
  the change without reading the diff first.
- **How it was validated.** The commands you ran and what they returned. "Tests
  pass" is not validation; name the suite and the result. If you verified
  something by hand, say what you checked and what you saw.
- **Risks, limitations, and next steps.** What could break, what the change
  deliberately does not cover, and what remains open. If you found a problem and
  left it, say so here rather than leaving it for the reviewer to find.

Write the title as a Conventional Commit, since squash merges take it as the
commit subject.

Do not hard-wrap issue and pull request bodies. GitHub renders a single newline
in a comment as a line break, so text wrapped for a file arrives on the page as
ragged short lines. Write each paragraph as one long line and let the page wrap
it. This is the opposite of the rule for files in this repository, which
markdownlint holds to 80 columns.

## Commits

Follow Conventional Commits: `fix:`, `feat:`, `docs:`, `ci:`, `test:`,
`refactor:`, `chore:`.

Commits are signed by the repository owner. Agents must not run `git commit`,
`git commit --amend`, `git rebase`, or anything else that creates or rewrites
commits. Prepare and verify the changes, then hand over the exact command to
run.

## Local checks

Run these before opening a pull request:

```bash
shellcheck -x install.sh update.sh uninstall.sh lib/dotfiles.sh tests/*.sh
bash tests/install-uninstall.sh
```

The lifecycle test uses temporary home and state directories and never touches
real user configuration. It also sets `DOTFILES_PRIVATE_ROOT` to a path that
does not exist, so a private overlay sitting beside the checkout cannot leak
into test fixtures. Keep that property when adding tests.

Markdown files are checked with markdownlint, which limits lines to 80
characters.

Target Bash 3.2. macOS ships that version, so associative arrays, `mapfile`, and
`${var^^}` are unavailable.

## Scope discipline

- Fix the problem in the issue. Unrelated improvements belong in their own
  issue.
- Do not add abstraction before there are two callers. A helper used once is
  harder to read than the code it replaced.
- Check whether something already exists before writing it.
  `dotfiles_install_link`, `dotfiles_sync_tree`, and the assertion helpers in
  the test suite cover most of what a new change needs.
- Prefer extending an existing function over adding a parallel one that does
  almost the same thing.
- Keep the installer's behaviour predictable: idempotent, quiet when there is
  nothing to do, and explicit about every path it touches.

## Secrets

No key material, credentials, identities, or host-specific values belong in this
repository. They live in the private overlay, which is a separate repository.

A signing key setting should name a public key or a key ID. Private keys stay in
an agent, credential manager, or keyring. If you find a secret in the history,
rotating it is part of the fix; removing the commit is not enough on its own.
