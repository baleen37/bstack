---
name: github-create-issue
description: >-
  Create a GitHub issue with minimal input. Infers repo from current
  directory and labels from description keywords.
---

# GitHub: Create Issue

## Keywords

create github issue, github issue, file github issue, open github issue, new github issue, gh issue

## Overview

Create a GitHub issue from a one-line description. Infers the repo from the current git directory
and the label from keywords.

**Use this skill when:** The user wants to create a new GitHub issue and provides a description.

---

## Workflow

### Step 1: Determine Repo

Infer the repo from the current git remote.

```bash
gh repo view --json nameWithOwner -q '.nameWithOwner'
```

If not in a git repo or no remote, ask the user.

---

### Step 2: Determine Labels

Infer labels from the description keywords.

| Keywords | Label |
|----------|-------|
| bug, error, crash, broken, fix, fail, wrong | bug |
| feature, add, new, implement, support | enhancement |

If no keywords match, create without labels.

---

### Step 3: Create the Issue

```bash
gh issue create --repo <owner/repo> --title "<user's description>" [--label <label>]
```

**Output format:**

```text
#<number> created
https://github.com/<owner/repo>/issues/<number>
```

---

## When NOT to Use This Skill

- Updating an existing GitHub issue → use `github-update-issue`
- Creating a Jira issue → use `jira-create-issue`
