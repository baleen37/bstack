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
# If on main/master: automatically create a branch from the last commit message
#   git checkout -b <type>/<short-description>  (derived from commit subject)
# Never ask the user — just create it.

# 2) commit
git add <specific-files>
git commit -m "type(scope): summary"

# 3) conflict check (read-only)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/check-conflicts.sh"

# 4) push
git push -u origin HEAD

# 5) detect PR template (check in order)
# .github/PULL_REQUEST_TEMPLATE.md → PULL_REQUEST_TEMPLATE.md → default format
# If found: read it, fill each section with actual change details, preserve empty checkboxes (- [ ]) as-is
# If not found: use default format (see PR Body Format below)

# 6) create PR (do not hardcode --base main)
# Body: filled template or default format
PR_URL=$(gh pr create --title "$(git log -1 --pretty=%s)" --body "<filled body>")

# 7) verify
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/verify-pr-status.sh"
# exit 0: done
# exit 1: broken — use me:pr-pass
# exit 2: CI still running — continue to step 8

# 8) auto-merge (optional, if requested in arguments)
# Try --auto first; if it fails, fall back to watch + direct merge
gh pr merge --auto --squash || {
  gh pr checks --watch
  "${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/verify-pr-status.sh"
  # exit 0: safe to merge directly
  # exit 1: broken — use me:pr-pass
  gh pr merge --squash
}
```

## Stop Conditions

- No changes to commit and no unpushed commits
- Conflict check failed
- Required CI failed
- State-changing follow-up not approved by user

## PR Body Format

### If template found (`.github/PULL_REQUEST_TEMPLATE.md` or `PULL_REQUEST_TEMPLATE.md`)

Read the template file and use its structure as the body skeleton. Fill each section with actual change details. Preserve empty checkboxes (`- [ ]`) exactly as-is — do not check them.

### If no template found (default)

- Summary: 1-2 sentences max
- Changes: Bullet list
- Tests: What you verified
- Breaking: Only if applicable
