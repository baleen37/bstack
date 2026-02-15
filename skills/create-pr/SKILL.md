---
name: create-pr
description: This skill should be used when the user asks to "create a PR", "make a pull request", "open a PR", "submit PR", or requests complete git commit→push→PR workflow.
---

# Create PR

## Overview

Commit → Push → PR workflow with mandatory safety checks.

Urgency is reason to follow rules MORE strictly, not to bypass them. The moment the process feels "too slow" is exactly when skipping it causes the most delay.

## Pre-Flight Checks (MANDATORY)

Before any commit:

1. Verify current branch is NOT main/master — STOP if it is
2. Review uncommitted changes with `git status`
3. Fetch remote: `git fetch origin`
4. Detect conflicts proactively:

```bash
MAIN=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
if git merge-tree $(git merge-base HEAD "origin/$MAIN") HEAD "origin/$MAIN" | grep -q '<<<<<<<'; then
  echo "CONFLICTS DETECTED - resolve before PR"
  exit 1
fi
```

Never skip conflict detection. Push failures waste more time than a 5-second check.

## Workflow

1. **Stage specific files** — never `git add -A` without prior `git status`
2. **Commit** with Conventional Commits format: `type(scope): description`
3. **Push** to remote: `git push -u origin HEAD`
4. **Create PR** via `gh pr create --title "..." --body "..." --web`
5. **Enable auto-merge** if the repo supports it: `gh pr merge --auto --squash` — skip if auto-merge is disabled or no status checks exist

## Conflict Resolution

When conflicts are detected in pre-flight:

1. Rebase onto main: `git rebase origin/$MAIN`
2. Resolve conflicts and stage resolved files
3. Continue rebase: `git rebase --continue`
4. **MANDATORY: Run project tests after rebase** — rebase changes code, untested = broken PR
5. Force-push safely: `git push --force-with-lease origin HEAD`

## Rationalizations Table

| Excuse | Reality |
|--------|---------|
| "Time pressure, skip conflict check" | Pre-flight check takes 5 seconds. Push failure wastes 5 minutes. |
| "GitHub will detect conflicts after push" | Reactive detection = wasted work. Proactive detection = immediate fix. |
| "Set up auto-merge later" | Handle during PR creation. No reason to split into two steps. |
| "Simple change, should be fine" | Change complexity ≠ conflict likelihood. Always check. |
| "Can skip tests after rebase" | Conflict resolution changes code. Untested = broken PR. |
| "Production emergency! Must bypass rules" | Urgency = reason to follow rules MORE strictly. Bypass causes more delay. |

## Red Flags

- Skipping `git fetch` before committing
- Running `git push` before conflict check
- Mentioning "might miss this" without actually checking
- Creating PR first, then thinking about auto-merge
- Using "hurry" or "urgent" as justification for skipping steps
- Skipping tests after conflict resolution
- Thinking "small conflict, should be fine"

**Any of these = STOP and run pre-flight checks.**
