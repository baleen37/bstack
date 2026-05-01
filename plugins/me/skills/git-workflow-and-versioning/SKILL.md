---
name: git-workflow-and-versioning
description: Trunk-based development, atomic commits, change sizing (~100 lines), and the commit-as-save-point pattern. Use when making any code change.
---

# Git Workflow and Versioning

## Overview

Treat commits as save points. Keep changes small (~100 lines), atomic, and revertable. Work on trunk; branches are short-lived.

## Core Principles

- **Trunk-based**: short-lived branches, frequent integration to main.
- **Atomic commits**: one logical change per commit. Each commit compiles and passes tests.
- **Sizing**: target ~100 lines of diff. If larger, split.
- **Save points**: commit when you have something working, even if incomplete. Cheap to revert beats hard to debug.
- **Conventional Commits**: `type(scope): description` — enables automated versioning.

## When to Commit

- A test passes that didn't before.
- A refactor compiles and existing tests still pass.
- Before a risky change, so you can revert cleanly.
- End of a logical step, even if the feature isn't done.

## When to Split

- Diff exceeds ~100 lines of meaningful change.
- Commit message needs "and" to describe it.
- Mixed concerns (refactor + feature, fix + cleanup).

## Anti-patterns

- "WIP" commits pushed to main.
- Mega-commits that touch unrelated files.
- Long-lived feature branches that drift from trunk.
- Force-pushing shared branches.
