<!-- markdownlint-disable-file MD041 -->
<!--
Title must be a Conventional Commit, since a squash merge takes it as the
subject. Example:
  fix: publish configuration to a prefix instead of linking the checkout

Do not hard-wrap what you write below. GitHub renders a single newline in a
comment as a line break, so wrapped text arrives as ragged short lines. Write
each paragraph as one long line and let the page wrap it.

Examples use fictional paths and identities: ~/src/dotfiles,
personal@example.com. This repository is public. Output shown in an example is
copied from the code that prints it, not written from memory.
-->

Closes #

## Problem

<!--
What is broken or missing, and why it matters. A reviewer should understand the
change before reading the diff.
-->

## Before

<!--
A real configuration or command, and the wrong result it produces. For a change
with no observable behaviour, documentation for instance, this is what a reader
had.
-->

```text
```

## After

<!-- The same input, and the right result. -->

```text
```

## Implementation

<!--
How it works, and the decisions a reviewer would otherwise have to reconstruct
from the diff.
-->

## Validation

<!--
The commands you ran and what they returned. "Tests pass" is not validation:
name the suite and the result. If you checked something by hand, say what you
looked at and what you saw.
-->

```text
```

## Not covered

<!--
What could break, what this deliberately leaves out, and what stays open. If you
found a problem and left it, record it here rather than letting the reviewer
discover it. Write "none" only when you have actually considered the question.
-->

## Checklist

- [ ] `bash scripts/lint.sh` passes
- [ ] `bash tests/install-uninstall.sh` passes
- [ ] Nothing under `$HOME` resolves into the source checkout
- [ ] No key material, credentials, or identities added to this repository
