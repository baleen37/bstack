---
name: create-pr
description: Use when the user asks to "create a PR", "create pull request", "open a PR", "submit a PR", "make a pull request", "merge PR", or requests complete git workflow including commit, push, and PR creation
---

# Create PR

## Overview

Full PR flow: pre-flight → commit → push → PR creation → wait-for-merge.

If wait-for-merge reports a failure, use `me:pr-pass` to fix it.

## When to Use

- User asks to create/open/submit a PR
- User asks for commit → push → PR workflow
- User requests "auto merge" after PR creation

## Workflow

```bash
# 1) pre-flight (run in parallel: git status, git branch --show-current, git log --oneline -5)
# If on main/master: automatically create a branch from the last commit message
#   git checkout -b <type>/<short-description>  (derived from commit subject)
# Never ask the user — just create it.
# Then run preflight check (blocking):
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/preflight-check.sh"

# 2) commit
git add <specific-files>
git commit -m "type(scope): summary"

# 3) push
git push -u origin HEAD

# 4) detect PR template (check in order)
# .github/PULL_REQUEST_TEMPLATE.md → PULL_REQUEST_TEMPLATE.md → default format
# If found: read it, fill each section with actual change details, preserve empty checkboxes (- [ ]) as-is
# If not found: use default format (see PR Body Format below)
# Then create PR and enable auto-merge:
gh pr create --title "$(git log -1 --pretty=%s)" --body "<filled body>"
gh pr merge --auto --squash || gh pr merge --squash

# 5) wait for merge
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/wait-for-merge.sh"
# exit 0: merged — done
# exit 0: CI passed, awaiting review — done (auto-merge will handle it)
# exit 1: CI failed — invoke me:pr-pass (see CI Failure Handling below)
```

## CI Failure Handling

When `wait-for-merge.sh` exits 1 (CI failed):

1. Invoke `me:pr-pass` to fix the failure
2. `me:pr-pass` will push a fix and CI will re-run
3. After `me:pr-pass`, re-run `wait-for-merge.sh`

**Stop condition:** If `me:pr-pass` cannot determine a fix (ambiguous root cause, requires architecture decisions, touches unrelated systems), STOP and report to user with:
- What failed
- Why it's too complex to auto-fix
- What the user needs to decide

## Recovery

If preflight-check reports BEHIND or conflicts, sync first:
```bash
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/sync-with-base.sh"
```

To check PR status without modifying anything:
```bash
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/verify-pr-status.sh"
```

## Stop Conditions

- No changes to commit and no unpushed commits
- Pre-flight check failed (BEHIND or conflicts) and sync-with-base also fails
- `me:pr-pass` cannot determine a clear fix (complex/ambiguous failure)
- `me:pr-pass` has been invoked twice with no progress (likely flaky or systemic)

## PR Body Format

### If template found (`.github/PULL_REQUEST_TEMPLATE.md` or `PULL_REQUEST_TEMPLATE.md`)

Read the template file and use its structure as the body skeleton. Fill each section with actual change details. Preserve empty checkboxes (`- [ ]`) exactly as-is — do not check them.

### If no template found (default)

- Summary: 1-2 sentences max
- Changes: Bullet list
- Tests: What you verified
- Breaking: Only if applicable
