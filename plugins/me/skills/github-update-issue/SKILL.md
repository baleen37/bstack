---
name: github-update-issue
description: >-
  Update a GitHub issue — change status, add comments, edit labels,
  or assign. Infers repo from current directory.
---

# GitHub: Update Issue

## Keywords

update github issue, close github issue, reopen github issue, github comment, github label, assign

## Overview

Update a GitHub issue with minimal input. Supports closing/reopening, comments, label changes,
and assignment. Infers the repo from the current git directory.

**Use this skill when:** The user wants to update an existing GitHub issue.

---

## Workflow

### Step 1: Determine Repo

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

If not in a git repo or no remote, ask the user.

---

### Step 2: Determine Issue Number

**Strategy (in order):**

1. **User provided it:** If the user included a number (e.g., `#42` or `42`), use it directly.

2. **Branch name:** Extract issue number from branch name.

   ```bash
   git branch --show-current
   ```

   Match pattern: `#?\d+` or `issue-\d+` in the branch name
   (e.g., `fix/42-login-bug` → `42`).

3. **Fallback:** Ask the user for the issue number.

---

### Step 3: Determine Action

Based on the user's request, perform one or more:

#### Close / Reopen

```bash
gh issue close <number> --repo <owner/repo> [--reason "completed"|"not_planned"]
gh issue reopen <number> --repo <owner/repo>
```

#### Add Comment

```bash
gh issue comment <number> --repo <owner/repo> --body "<text>"
```

#### Edit Labels

```bash
gh issue edit <number> --repo <owner/repo> --add-label "<label>"
gh issue edit <number> --repo <owner/repo> --remove-label "<label>"
```

#### Assign

```bash
gh issue edit <number> --repo <owner/repo> --add-assignee "<username>"
```

---

### Step 4: Confirm

**Output format:**

```text
#<number> updated: <action summary>
https://github.com/<owner/repo>/issues/<number>
```

---

## When NOT to Use This Skill

- Creating a new GitHub issue → use `github-create-issue`
- Updating a Jira issue → use `jira-update-issue`
