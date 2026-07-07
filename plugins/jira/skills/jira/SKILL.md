---
name: jira
description: Use Jira through a slim Atlassian MCP facade for issue lookup, triage, creation, comments, and lightweight status reporting.
---

# Jira

Slim Atlassian MCP facade with compact key/value text output.

## Workflow

1. Use `sites` to get `site`; issue tools take `key` like `SEARCH-14010`.
2. Search narrow JQL before creating or updating.
3. For writes, show the exact change before `confirm: true`.
4. Prefer `comment` or `update` over duplicate `create`.

## Tools

- `auth`: auth check.
- `sites`: site ids; `scopes: true` for scopes.
- `projects`: projects; `types: true` for issue types.
- `search`: JQL list with `key`, `type`, `status`, `summary`.
- `issue`: one issue; `meta: true` for assignee/priority, `desc: true` for description.
- `create`: requires `project`, `type`, `summary`, `confirm`; optional `description`, `fields`.
- `comment`: add comment `body`; pass comment `id` to update.
- `update`: update `fields` after confirmation; description is `fields.description`.
- `transitions`: available transitions; `to: true` for target status.
- `transition`: transition by `id` after confirmation.

No issue/comment delete tool is exposed. Use `transition`, `update`, or corrective `comment`.

## Patterns

- Project JQL: `project = KEY ORDER BY updated DESC`
- Active JQL: `project = KEY AND statusCategory != Done ORDER BY updated DESC`
- Duplicate check: search summary terms, labels/components, and exact errors.
- Backlog: create independently actionable Epic/Story/Bug/Task with acceptance criteria.

## Safety

- Avoid broad JQL and unrelated private issue content.
- State when a conclusion is inferred rather than shown by Jira.
