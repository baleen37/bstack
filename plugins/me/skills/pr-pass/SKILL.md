---
name: pr-pass
description: Use when a PR is broken and needs to be fixed — CI failures, merge conflicts, BEHIND base branch, or failing tests.
---

# PR Pass

Diagnose and fix a broken PR.

## Diagnose (run in parallel)

```bash
gh pr checks
gh pr view --json mergeable,mergeStateStatus
```

## Fix by Symptom

**CI failure**
```bash
gh run view <run-id> --log-failed  # read logs
# fix, commit, push
gh pr checks --watch
```

**Failing tests** — run locally first, never fix blind
```bash
<test command>
# fix, commit, push
gh pr checks --watch
```

**Conflict (DIRTY)**
```bash
git fetch origin && git merge origin/<base>
# resolve, commit, push
```

**BEHIND base**
```bash
git fetch origin && git merge origin/<base-branch>
git push
```

## Done

`gh pr checks --watch` exits 0.

## Stop and Ask

- Can't reproduce test failure locally
- Conflict resolution is ambiguous
- Fix requires significant refactor
