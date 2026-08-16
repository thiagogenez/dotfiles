---
name: dotfiles-change
description: >-
  Plan, implement, review, and verify focused changes to this Bash dotfiles
  installer. Use for install, update, uninstall, or doctor behavior; symlink and
  backup ownership; the public/private boundary; contributor workflow; or
  cross-platform tests.
---

# Dotfiles change

Read `AGENTS.md` and the linked issue before changing files. Treat `AGENTS.md`
as canonical when this workflow and the repository rules differ.

## Ground the change

1. Confirm that the issue states the problem, proposal, and motivation.
2. Inspect the current implementation and run the smallest command that exposes
   the existing behavior. Do not rely on results from an earlier session.
3. State the observable acceptance conditions and explicit non-goals.
4. If two interpretations would change behavior, present them side by side and
   resolve the ambiguity before editing.

## Plan from evidence

Write steps that name the exact files or functions to change and the command
that will verify each step. Keep the plan inside the issue scope.

Before adding anything, search for an existing helper, assertion, fixture, or
documentation section that owns the behavior. Prefer extending that owner to
creating a parallel mechanism.

## Implement narrowly

- Keep the diff as small as the acceptance conditions allow.
- Preserve Bash 3.2 compatibility and the bash-plus-git runtime boundary.
- Preserve idempotency and explicit ownership of every path touched.
- Keep active links inside the installed prefixes, never the source checkout.
- Keep identities, hosts, credentials, and private payloads in the private
  overlay.
- Add a regression assertion at the narrowest layer that proves the behavior.
- Do not add speculative abstractions, dependencies, or unrelated cleanup.

## Review the result

Review only lenses earned by the change:

- behavior, failure modes, and rollback;
- path, symlink, backup, and uninstall ownership;
- public/private boundary and secret exposure;
- Bash 3.2 and macOS/Linux portability;
- accuracy of user-facing output and documentation.

A finding must name a file and line, assign impact, describe a concrete failure
scenario, and propose a fix. Merge duplicate findings and discard preferences
that do not affect the issue's acceptance conditions.

For destructive, security-sensitive, or cross-platform changes, request an
independent review when the environment and user allow it. Small documentation
or test-only changes do not require a review ceremony.

## Verify and stop

Run the focused regression first, then every local check from `AGENTS.md` before
handoff. Report each command and its actual result. If a check cannot run, say
why and what remains unverified.

Stop when the acceptance conditions pass. Report:

- files changed and the behavior they now own;
- validation results;
- deliberate exclusions or follow-up issues;
- the exact signed commit command for the repository owner.

Never create or rewrite a commit. Never broaden the change merely because the
review exposed an unrelated improvement.

This workflow selectively adapts planning and verification practices from
<https://github.com/thiagogenez/vibe-coding-toolkit>.
