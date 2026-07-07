---
name: jira
description: Use Jira through a slim Atlassian MCP facade for issue lookup, triage, creation, comments, and lightweight status reporting.
---

# Jira

Use the slim Jira MCP facade configured by this plugin. It connects to Atlassian MCP underneath and exposes compact tools instead of the full Jira API surface.

## Workflow

1. Identify the Jira site, project key, and target issue type before querying or writing.
2. Search with focused JQL before creating or updating issues.
3. Summarize matching issues before deciding whether a new issue is needed.
4. For writes, show the exact intended change and wait for user confirmation before setting `confirmed: true`.
5. Prefer comments or updates on an existing issue over creating duplicates.

## Tools

- `jira_auth_status`: check the active Atlassian MCP authentication.
- `jira_list_sites`: list accessible Atlassian sites and Cloud IDs.
- `jira_list_projects`: list visible Jira projects with compact metadata.
- `jira_search_issues`: search JQL and return compact issue cards.
- `jira_get_issue`: fetch one issue with a narrow field list.
- `jira_create_issue`: create one issue after confirmation.
- `jira_comment_issue`: add one comment after confirmation.

## Query Patterns

- Project scope: `project = KEY ORDER BY updated DESC`
- Active work: `project = KEY AND statusCategory != Done ORDER BY priority DESC, updated DESC`
- Duplicate check: combine project, component, label, summary terms, and exact error text.
- Status report: group counts by status category, then cite only representative issues.

## Write Patterns

- Create: confirm project, issue type, summary, description, labels, parent, and assignee first.
- Comment: include only the new evidence or decision; avoid restating the whole thread.
- Update: read the current issue first, then propose the smallest field change.
- Transition: inspect available transitions before moving an issue.

## Backlog

- Break specs into independently actionable Epic, Story, Bug, or Task candidates.
- Keep acceptance criteria and validation steps concrete.
- Create parent issues before children only after the user confirms the hierarchy.

## Safety

- Do not expose private issue content outside the requested context.
- Avoid broad JQL that pulls unrelated project data.
- State when a conclusion is inferred rather than directly shown by Jira data.
