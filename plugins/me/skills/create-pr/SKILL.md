---
name: create-pr
description: Use when the user asks to "create a PR", "create pull request", "open a PR", "submit a PR", "make a pull request", "merge PR", or requests complete git workflow including commit, push, and PR creation
---

# Create PR

## Overview

Full PR flow: pre-flight → commit → conflict check → push → PR creation → verify → (optional) auto-merge.

If verify reports a broken state (BEHIND, DIRTY, failed checks), use `me:pr-pass` to fix it.

## When to Use

- User asks to create/open/submit a PR
- User asks for commit → push → PR workflow
- User requests "auto merge" after PR creation

## Workflow

```bash
# 1) pre-flight (run in parallel: git status, git branch --show-current, git log --oneline -5)
# Check: not on main/master, has changes to commit

# 2) commit
git add <specific-files>
git commit -m "type(scope): summary"

# 3) conflict check (read-only)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/check-conflicts.sh"

# 4) push
git push -u origin HEAD

# 5) create PR (do not hardcode --base main)
# Body: 1-2 sentence summary, bullet list of changes, test evidence
PR_URL=$(gh pr create --title "$(git log -1 --pretty=%s)" --body "<short summary>")

# 6) verify
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/verify-pr-status.sh"
# exit 0: done
# exit 1: broken — use me:pr-pass
# exit 2: CI still running
gh pr checks --watch

# 7) auto-merge (optional, if requested in arguments)
gh pr merge "${PR_URL##*/}" --auto --squash
```

## Stop Conditions

- On `main`/`master`
- No changes to commit
- Conflict check failed
- Required CI failed
- State-changing follow-up not approved by user

## PR Body Format

- Summary: 1-2 sentences max
- Changes: Bullet list
- Tests: What you verified
- Breaking: Only if applicable
