---
name: pr-pass
description: Use when a PR is broken and needs to be fixed — CI failures, merge conflicts, BEHIND base branch, or failing tests.
---

# PR Pass

Diagnose and fix a broken PR.

## Diagnose

```bash
# Single call — all needed fields
gh pr view --json state,mergeable,mergeStateStatus
```

- `MERGED` → done, nothing to fix
- `CLOSED` → reopen if needed
- `OPEN` + `UNKNOWN` → CI settling, re-check in a few seconds

## Fix by Symptom

**CI failure** — if `wait-for-merge.sh` printed a `run-id`, use it directly:
```bash
gh run view <run-id> --log-failed 2>&1 | grep -A3 "not ok\|Error\|FAILED" | head -40
# fix, commit, push
gh pr checks --watch > /dev/null 2>&1; echo "CI: $?"
```

**Failing tests** — run locally first, never fix blind:
```bash
<test command>
# fix, commit, push
```

**Conflict (DIRTY)**
```bash
git fetch origin && git merge origin/<base>
# resolve, commit, push
```

**BEHIND base**
```bash
git fetch origin && git merge origin/<base> && git push
```

## Done

`gh pr checks --watch` exits 0 (suppress output, check exit code only).

## Stop and Ask

- Can't reproduce test failure locally
- Conflict resolution is ambiguous
- Fix requires significant refactor
