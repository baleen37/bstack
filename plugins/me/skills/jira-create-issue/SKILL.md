---
name: jira-create-issue
description: >-
  Create a Jira issue with minimal input. Infers project key from
  repo/branch name and issue type from description keywords.
  Requires Atlassian MCP connection.
---

# Jira: Create Issue

## Keywords

create jira issue, create jira ticket, jira issue, jira ticket, file jira issue, new jira ticket

## Overview

Create a Jira issue from a one-line description. Automatically infers the project key and issue type
so the user doesn't have to specify them.

**Use this skill when:** The user wants to create a new Jira issue and provides a description.

---

## Workflow

Follow this 4-step process:

### Step 1: Resolve Cloud ID

Get the Atlassian cloud ID to use for API calls.

```text
getAccessibleAtlassianResources()
```

- **Single resource:** Use it automatically.
- **Multiple resources:** Ask the user which one to use.

---

### Step 2: Determine Project Key

Infer the project key from the current context.

**Strategy (in order):**

1. **Branch name:** Extract prefix from branch name (e.g., `PROJ-123-fix-login` → `PROJ`)

   ```bash
   git branch --show-current
   ```

   Match pattern: branch name starts with `[A-Z]+-\d+` → extract the alphabetic prefix.

2. **Repo name:** Match repo name against available Jira projects.

   ```bash
   basename $(git rev-parse --show-toplevel)
   ```

3. **Visible projects:** Fetch project list and match.

   ```text
   getVisibleJiraProjects(cloudId)
   ```

   If there's only one project, use it. Otherwise, present the list and ask.

4. **Fallback:** Ask the user which project to use.

---

### Step 3: Determine Issue Type

Infer the issue type from the description keywords.

| Keywords | Issue Type |
| -------- | ---------- |
| bug, error, crash, fix, broken, 404, 500, fail, exception, wrong | Bug |
| everything else | Task |

Verify the issue type exists in the project:

```text
getJiraProjectIssueTypesMetadata(cloudId, projectKey)
```

If the inferred type doesn't exist, fall back to the first available non-Epic, non-Subtask type.

---

### Step 4: Create the Issue

```text
createJiraIssue(
  cloudId=<cloudId>,
  projectKey=<projectKey>,
  issueTypeName=<issueType>,
  summary=<user's description>
)
```

**Output format:**

```text
<ISSUE-KEY> created
https://<site>.atlassian.net/browse/<ISSUE-KEY>
```

---

## When NOT to Use This Skill

- Triaging or searching for existing issues → use `triage-issue`
- Creating issues from a spec → use `spec-to-backlog`
- Creating issues from meeting notes → use `capture-tasks-from-meeting-notes`
