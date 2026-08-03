---
name: twg-jira
description: Use the twg CLI for Jira reads and safe Jira mutations.
---

# twg-jira

Use with the root `twg` skill whenever Jira is the source of truth. This skill covers Jira only.

## Routing

| Intent | Command |
| --- | --- |
| Jira-only fuzzy text | `twg jira workitem search "text" --limit 20` |
| Explicit JQL | `twg jira workitem query --jql 'project = PROJ ORDER BY updated DESC'` |
| Semantic Jira discovery | `twg search "text" --app jira` |
| Known issue read | `twg jira workitem get PROJ-123` |
| Create | `twg jira workitem create ... --yes` after metadata/read confirmation and explicit user approval |
| Comments | `twg jira workitem comment create/update ...` after reading current state |

Use `twg help describe "<command path>"` for exact command grammar. Issue keys are positional for `twg jira workitem get`; do not guess flags, fields, or transition names.

Search results are candidate anchors. Use a native `twg jira workitem get PROJ-123` read to confirm final fields, status, comments, and URLs.

## Output boundaries

- Use bounded, human-readable output by default for searches and reads.
- Limit result counts with `--limit` or the command's appropriate range before expanding a query.
- Use `--output json` only when filtering results or collecting machine-readable evidence requires it.

## Safe mutations

- Read current state before every create, update, comment, or transition.
- Before create or update, inspect the required field metadata and provide returned custom field IDs rather than guessed display names.
- Before a transition, discover available transitions rather than guessing one.
- For every state-changing operation, including create, update, comment, transition, link, and any similar mutation, first show the exact change, target, and expected impact to the user.
- Execute a state-changing operation only after the user explicitly approves the shown mutation; do not execute it before approval.
- Apply this rule whether or not --yes is present. The `--yes` flag never substitutes for explicit user approval.
- Reads and searches remain allowed without this approval.
- Verify a completed mutation with a native issue read and report the resulting issue key and URL.

Do not claim Confluence or other Atlassian product coverage.
