<!-- markdownlint-disable-file MD041 -->
<!--
Title must be a Conventional Commit, since a squash merge takes it as the
subject. Example:
  fix: publish configuration to a prefix instead of linking the checkout

Do not hard-wrap what you write below. GitHub renders a single newline in a
comment as a line break, so wrapped text arrives as ragged short lines. Write
each paragraph as one long line and let the page wrap it.
-->

## Issue

Closes #

## What changed

<!--
The substance, not a file list. A reviewer should understand the change before
reading the diff.
-->

## How it was validated

<!--
The commands you ran and what they returned. "Tests pass" is not validation:
name the suite and the result. If you checked something by hand, say what you
looked at and what you saw.
-->

```text
```

## Risks, limitations, and next steps

<!--
What could break, what this deliberately does not cover, and what stays open. If
you found a problem and left it, record it here rather than letting the reviewer
discover it. Write "none" only when you have actually considered the question.
-->

## Checklist

- [ ] `shellcheck -x` passes on the entry points, `lib/`, and `tests/`
- [ ] `bash tests/install-uninstall.sh` passes
- [ ] Nothing under `$HOME` resolves into the source checkout
- [ ] No key material, credentials, or identities added to this repository
