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
- [Issues](#issues)
- [Pull requests](#pull-requests)
- [Writing issues and pull requests](#writing-issues-and-pull-requests)
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

## Issues

Three sections, in this order. The issue forms produce them.

- **Problem.** What is wrong, with a console example showing the failure. Paste
  the command and its output rather than describing them.
- **Proposal.** What should change, specific enough that someone else could
  implement it.
- **Motivation.** Why it is worth doing, and why this shape of fix rather than a
  weaker one.

Extra sections are fine when a specific issue earns them, such as a constraint
the implementation must respect or an approach already tried and reverted. The
three above are the spine and come first.

Do not add an "alternatives considered" section. A rejected approach belongs in
the proposal, as the reason the proposed one is shaped the way it is.

## Pull requests

Six sections, in this order.

- **Problem.** What is broken or missing. Link the issue, and use `Closes #N`
  when the pull request resolves it.
- **Before.** A real configuration or command, and the wrong result it produces.
- **After.** The same input, and the right result.
- **Implementation.** How it works, and the decisions a reviewer would otherwise
  have to reconstruct from the diff.
- **Validation.** The commands you ran and what they returned. "Tests pass" is
  not validation; name the suite and the result. If you verified something by
  hand, say what you checked and what you saw.
- **Not covered.** What could break, what the change deliberately leaves out,
  and what stays open. If you found a problem and left it, say so here rather
  than letting the reviewer find it.

`Before` and `After` show the same input twice so a reviewer can judge the fix
without reconstructing the failure. Where a change has no observable behaviour,
documentation for instance, they become what a reader had and what a reader
gets. A section with nothing honest to put in it should be dropped, not filled.

`Found on the way` is a useful seventh section for something true that the
change did not set out to find.

Write the title as a Conventional Commit, since squash merges take it as the
commit subject.

## Writing issues and pull requests

Examples use fictional paths and identities: `~/src/dotfiles`,
`personal@example.com`, `build.example.com`. This repository is public, and a
real path names a machine and a person.

Output quoted in an example is copied from the code that produces it. Do not
invent a plausible message; find the `printf` and use what it prints.

Do not hard-wrap issue and pull request bodies. GitHub renders a single newline
in a comment as a line break, so text wrapped for a file arrives on the page as
ragged short lines. Write each paragraph as one long line and let the page wrap
it. This is the opposite of the rule for files in this repository, which
markdownlint holds to 80 columns.

## Commits

Conventional Commits, written terse.

- `<type>(<scope>): <imperative summary>`, at most 50 characters, hard cap 72
- Types: `fix`, `feat`, `docs`, `ci`, `test`, `refactor`, `chore`, `perf`,
  `build`, `style`, `revert`
- Imperative mood: "add", "fix", "remove", never "added" or "adds"
- Lowercase after the colon, and no trailing period
- Body only when the diff does not make the reason obvious, wrapped at 72
- Always a body for breaking changes, security fixes, migrations, and reverts,
  because whoever debugs one of those later needs the context
- Reference issues at the end: `Closes #42`, `Refs #17`
- Leave out "this commit does X", first person, and AI attribution

`tests/commit-message.sh` checks what is mechanically checkable. Imperative mood
is not, so it stays a convention the check cannot enforce for you.

Commits are signed by the repository owner. Agents must not run `git commit`,
`git commit --amend`, `git rebase`, or anything else that creates or rewrites
commits. Prepare and verify the changes, then hand over the exact command to
run.

## Local checks

Run these before opening a pull request:

```bash
shellcheck -x ./*.sh lib/*.sh tests/*.sh
shfmt -d -i 4 -ci -kp ./*.sh lib/*.sh tests/*.sh
bash tests/install-uninstall.sh
bash tests/architecture.sh
bash tests/commit-message.sh
```

`./doctor.sh` reports whether the current machine's installation is healthy. It
is read-only and never repairs; `./update.sh` does that.

`shellcheck` covers correctness and `shfmt` covers layout; they do not overlap.
Neither is required to contribute: CI runs the same commands, and skipping them
locally only costs a round trip.

Nothing in this pipeline may become a runtime dependency of the installer.
`install.sh` runs with bash and git alone, and it has to stay that way, because
it manages SSH and GnuPG configuration on machines that may have nothing else
installed. Tools belong in CI and on contributor machines, never in the
installer's execution path.

## Tooling

All optional. The rules in this file are written out in full and CI is what
decides, so a clone needs nothing beyond bash and git. These only shorten the
loop.

| Tool | What it does here |
| --- | --- |
| shellcheck | correctness of shell |
| shfmt | layout of shell |
| caveman | writes commit messages in the form above |
| humanizer | strips generated-text tells from issue and pull request prose |

```bash
brew install shellcheck shfmt

# <agent> is claude, codex, cursor, and so on
npx skills add JuliusBrussee/caveman -a <agent>
npx skills add blader/humanizer -a <agent>
```

The same installer serves each agent, so a tool added once behaves the same
whichever one is running.

These are suggestions, not requirements, and the last two install third-party
code from GitHub. Read what you are installing, and skip them freely: a pull
request written by hand and a pull request written with them are judged the
same way.

Should this repository ever ship a skill of its own, the content belongs in
`.agents/skills/<name>/SKILL.md`, with `.claude/skills/<name>` and
`.codex/skills/<name>` as relative symlinks to it. One copy, one symlink per
agent, so editing the skill reaches every agent at once. Git stores those
symlinks natively, so a clone needs no setup step.

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
