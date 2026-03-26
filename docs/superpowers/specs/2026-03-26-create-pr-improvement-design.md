# create-pr Skill Improvement Design

**Date:** 2026-03-26
**Scope:** `plugins/me/skills/create-pr/`
**Prerequisites:** Git 2.38+ (for `git merge-tree` exit code behavior)

## Goal

Prevent PR from getting blocked mid-flow by catching merge blockers before push, and fully automate the path from PR creation to merge completion without redundant checks.

## Problems with Current Flow

1. `check-conflicts.sh` only catches merge conflicts — BEHIND and branch protection violations slip through until post-PR-creation
2. `verify-pr-status.sh` re-checks conditions already covered by preflight, creating redundancy
3. The auto-merge path (step 7 + step 8) is split across two steps with complex exit-code branching
4. 8-step flow is longer than necessary

## New Flow (5 steps)

```
1. pre-flight     → preflight-check.sh (BEHIND + conflict + branch protection)
2. commit         → git add + git commit
3. push           → git push -u origin HEAD
4. PR create      → gh pr create + gh pr merge --auto --squash
5. wait-for-merge → wait-for-merge.sh (CI watch + merge confirmation)
```

`verify-pr-status.sh` is retained for use by `me:pr-pass` only — removed from create-pr flow.

## Scripts

### preflight-check.sh (replaces check-conflicts.sh)

Runs before push. Checks in order:

1. **BEHIND** — `git rev-list HEAD..origin/$BASE --count` — fails if branch is behind base
2. **Conflict** — `git merge-tree` (existing approach) — fails if merge would conflict
3. **Branch protection** — `gh api repos/{owner}/{repo}/branches/$BASE/protection` — reports required reviewers/checks so Claude knows what's needed before PR is approvable

Exit codes:
- `0` — all checks passed
- `1` — blocking issue found (BEHIND or conflict)
- `2` — environment error (no git repo, gh not authenticated, etc.)

Branch protection check is **advisory only** (non-blocking) — it surfaces requirements but doesn't fail the preflight, since those are resolved post-creation.

### wait-for-merge.sh (new)

Runs after PR creation and auto-merge is enabled.

```bash
gh pr checks --watch          # blocks until all CI checks complete
gh pr view --json state,url   # single state check
# MERGED → exit 0
# OPEN   → exit 0 (CI passed, awaiting review approval — auto-merge is set)
# CLOSED or CI failed → exit 1
```

No polling loop — `gh pr checks --watch` handles the blocking wait natively.

When CI passes but the PR remains OPEN (e.g., required reviewers haven't approved), this is a success — automation has done everything it can. The preflight advisory already informed the user about required reviewers.

## SKILL.md Changes

### Before (8 steps)
1. pre-flight
2. commit
3. conflict check (`check-conflicts.sh`)
4. push
5. detect PR template
6. create PR
7. verify (`verify-pr-status.sh`)
8. auto-merge + re-verify loop

### After (5 steps)
1. pre-flight + `preflight-check.sh`
2. commit
3. push
4. detect template + create PR + enable auto-merge (with fallback to direct merge)
5. `wait-for-merge.sh`

### Testing Strategy

- **preflight-check.sh:** Integration tests using temporary git repos (bare + clones) to verify BEHIND detection, conflict detection, and clean-merge scenarios
- **wait-for-merge.sh:** Static analysis tests only (gh API dependency makes integration testing impractical); manual verification checklist in implementation plan

## File Changes

| File | Action |
|------|--------|
| `scripts/preflight-check.sh` | New — replaces check-conflicts.sh |
| `scripts/check-conflicts.sh` | Deleted |
| `scripts/wait-for-merge.sh` | New |
| `scripts/verify-pr-status.sh` | Retained (pr-pass only) |
| `scripts/sync-with-base.sh` | Retained (pr-pass only) |
| `SKILL.md` | Updated workflow |
