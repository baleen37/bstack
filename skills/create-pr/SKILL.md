---
name: create-pr
description: Use when the user asks to "create a PR", "create pull request", "open a PR", "submit a PR", "make a pull request", "merge PR", or requests complete git workflow including commit, push, and PR creation
---

# Create PR

## Overview

Use this for full PR flow: pre-flight → commit → conflict check → push → PR creation → verify.

Keep verification read-only. Run sync only when verify reports `BEHIND`.

## When to Use

- User asks to create/open/submit a PR
- User asks for commit → push → PR workflow

## Minimal Workflow (/writing-skills)

```bash
# 1) pre-flight
git status
git branch --show-current
git log --oneline -5

# 2) commit
git add <specific-files>
git commit -m "type(scope): summary"

# 3) conflict check (read-only)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/check-conflicts.sh"

# 4) push
git push -u origin HEAD

# 5) create PR (do not hardcode --base main)
gh pr create --title "$(git log -1 --pretty=%s)" --body "<summary, details, tests>"

# 6) verify (read-only)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/verify-pr-status.sh"
```

## Status Handling

- verify exit `0`: merge-ready (`CLEAN` + required checks passed)
- verify exit `1`: action required (`BEHIND`, `DIRTY`, failed checks, unknown)
- verify exit `2`: pending (`BLOCKED`, `UNSTABLE`, checks running)

When `BEHIND`:

```bash
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/sync-with-base.sh"
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/verify-pr-status.sh"
```

## Stop Conditions

- On `main`/`master`
- No changes to commit
- Conflict check failed
- Required CI failed
- State-changing follow-up not approved by user

## PR Body Minimum

- Summary
- Technical details
- Test evidence
- Breaking changes (if any)
