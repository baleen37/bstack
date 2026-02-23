---
name: jira-update-issue
description: >-
  Update a Jira issue — change status, add comments, or edit fields.
  Infers issue key from branch name.
  Requires Atlassian MCP connection.
---

# Jira: Update Issue

## Keywords

update jira issue, jira status, transition jira, jira comment, edit jira issue, change jira status

## Overview

Update a Jira issue with minimal input. Supports status transitions, comments, and field edits.
Infers the issue key from the current branch name when possible.

**Use this skill when:** The user wants to update an existing Jira issue (status, comment, or fields).

---

## Workflow

### Step 1: Resolve Cloud ID

```text
getAccessibleAtlassianResources()
```

- **Single resource:** Use it automatically.
- **Multiple resources:** Ask the user which one to use.

---

### Step 2: Determine Issue Key

Infer the issue key from the current context.

**Strategy (in order):**

1. **User provided it:** If the user included an issue key (e.g., `PROJ-123`), use it directly.

2. **Branch name:** Extract issue key from branch name.

   ```bash
   git branch --show-current
   ```

   Match pattern: `[A-Z]+-\d+` anywhere in the branch name
   (e.g., `feature/PROJ-123-login` → `PROJ-123`).

3. **Fallback:** Ask the user for the issue key.

---

### Step 3: Determine Action

Based on the user's request, perform one or more of the following:

#### Status Transition

1. Get available transitions:

   ```text
   getTransitionsForJiraIssue(cloudId, issueIdOrKey)
   ```

2. Match the user's intent to a transition (e.g., "start working" → "In Progress", "done" → "Done").

3. Execute:

   ```text
   transitionJiraIssue(cloudId, issueIdOrKey, transition={id: <transitionId>})
   ```

#### Add Comment

```text
addCommentToJiraIssue(cloudId, issueIdOrKey, commentBody=<text>)
```

#### Edit Fields

```text
editJiraIssue(cloudId, issueIdOrKey, fields={<fieldName>: <value>})
```

Common fields: `summary`, `description`, `priority`, `assignee`.

---

### Step 4: Confirm

**Output format:**

```text
PROJ-123 updated: <action summary>
https://<site>.atlassian.net/browse/PROJ-123
```

---

## When NOT to Use This Skill

- Creating a new Jira issue → use `jira-create-issue`
- Triaging bugs → use `triage-issue`
- Bulk issue creation from specs → use `spec-to-backlog`
