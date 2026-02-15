---
name: create-pr
description: Use when user requests "create PR", "make pull request", or you need to commit changes and open GitHub PR. Required before any git push for PR creation.
---

# Create PR

## Overview

**Commit → Push → PR workflow with mandatory safety checks.**

Time pressure is NOT an excuse to skip checks. "Hurry" means do it right the first time.

## Pre-Flight Checks (MANDATORY)

```bash
# 1. Current branch - STOP if main/master
BRANCH=$(git branch --show-current)
[[ "$BRANCH" =~ ^(main|master)$ ]] && echo "ERROR: Cannot PR from main/master" && exit 1

# 2. Uncommitted changes
git status --porcelain

# 3. Fetch and check for conflicts BEFORE committing
git fetch origin
MAIN=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')

# CRITICAL: Detect conflicts NOW, not after push fails
if ! git merge-tree $(git merge-base HEAD origin/$MAIN) HEAD origin/$MAIN | grep -q '<<<<<<<'; then
  echo "✓ No conflicts with $MAIN"
else
  echo "⚠ CONFLICTS DETECTED - must resolve before PR"
  exit 1
fi
```

## Workflow

```bash
# 1. Stage and commit
git add <specific-files>  # Never git add -A
git commit -m "type(scope): description"

# 2. Push
git push -u origin HEAD

# 3. Create PR
gh pr create \
  --title "$(git log -1 --pretty=%s)" \
  --body "..." \
  --web

# 4. Enable auto-merge if CI exists
gh pr merge --auto --squash  # After PR created
```

## Auto-merge Requirements

**Before running `gh pr merge --auto`:**

```bash
# Check repo settings
gh repo view --json autoMergeAllowed -q '.autoMergeAllowed'

# Check branch protection
gh api repos/{owner}/{repo}/branches/$MAIN/protection \
  --jq '.required_status_checks.contexts'
```

If auto-merge disabled or no status checks: skip `--auto` flag.

## Conflict Resolution

```bash
# If conflict detected in pre-flight
git rebase origin/$MAIN
# Fix conflicts
git add <resolved-files>
git rebase --continue

# MANDATORY: Verify changes after conflict resolution
# Run project's test/lint commands OR minimal smoke test
# Rebase changes code - MUST verify it still works

git push --force-with-lease origin HEAD
```

## Stop Conditions

- Running from main/master branch
- Conflicts with main (detected in pre-flight)
- Auto-merge requested but repo doesn't support it

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

## Pressure Is NOT Justification

```
Urgency ≠ Justification for rule bypass
Urgency = Reason to follow rules MORE strictly

Why:
- Rule bypass → additional delay → more urgent
- Rule compliance → done right once → actually faster
```

**Critical insight**: The moment you think "too urgent to follow process" is exactly when following process matters most.
