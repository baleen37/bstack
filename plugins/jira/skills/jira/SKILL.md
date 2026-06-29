---
name: jira
description: Use Jira through the official Atlassian MCP server for issue lookup, triage, creation, comments, and lightweight status reporting.
---

# Jira

Use the official Atlassian MCP server configured by this plugin.

## Workflow

1. Identify the Jira site/resource before querying or writing.
2. Search existing issues with focused JQL before creating a new issue.
3. For bug triage, search by error signature, component, and user-visible symptom.
4. For writes, show the intended summary, description, labels, and target project before calling a create or update tool.
5. Prefer adding comments to existing matching issues over creating duplicates.

## Essential Patterns

### Triage

- Search recent open and resolved issues before creating a bug.
- Compare summary, stack trace or error signature, affected component, environment, and regression window.
- If a likely duplicate exists, add a comment with the new evidence instead of creating another issue.

### Backlog

- Break specs into Epic, Story, and Task candidates before writing anything.
- Keep each ticket independently actionable with acceptance criteria and validation steps.
- Confirm project, issue type, parent, labels, and assignee before creating tickets.

### Status

- Use narrow JQL by project, owner, label, sprint, or status category.
- Report counts and representative issues, not long raw issue dumps.
- Separate blocked, in-progress, done, and needs-triage work.

## Safety

- Do not expose private issue content outside the user's requested context.
- Keep JQL narrow enough to avoid pulling unrelated project data.
- State when a result is from Jira data versus an inference.
