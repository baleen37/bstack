---
name: deprecation-and-migration
description: Code-as-liability mindset, compulsory vs advisory deprecation, migration patterns, and zombie code removal. Use when removing old systems, migrating users, or sunsetting features.
---

# Deprecation and Migration

## Overview

Code is liability, not asset. Every line is something to maintain, secure, and reason about. Removing old code is as valuable as shipping new code.

## Deprecation Modes

- **Advisory**: warning emitted, old path still works. Use when callers need time and you can afford to wait.
- **Compulsory**: hard cutoff with a date. Use when the old path blocks progress or carries risk.

Pick one explicitly. "Advisory forever" = zombie code.

## Migration Patterns

- **Expand → Migrate → Contract**: add the new path alongside the old, move callers, remove the old.
- **Strangler fig**: route traffic incrementally from old to new behind a flag.
- **Dual-write**: write to both systems during transition; read from old, then switch.
- **Backfill**: migrate historical data once new system is authoritative.

## Removal Checklist

- All known callers migrated (grep, telemetry, logs).
- Deprecation warnings in place for ≥ one release cycle.
- Removal date communicated to consumers.
- Rollback plan if the new path fails.

## Zombie Code Signals

- Feature flags stuck at 100% or 0% for months.
- "Old" / "Legacy" / "v1" in the name and a "v2" exists.
- No one remembers what calls it.
- Last meaningful change > 2 years ago.

When you find zombies: remove them, don't refactor them.

## Anti-patterns

- "We'll remove it later" without a date.
- Keeping old code "just in case" — git history is the just-in-case.
- Migrating callers but never deleting the old path.
