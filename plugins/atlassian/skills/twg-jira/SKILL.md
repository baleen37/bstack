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
| Create | `twg jira workitem create ... --yes` after metadata/read confirmation |
| Comments | `twg jira workitem comment create/update ...` after reading current state |

Use `twg help describe "<command path>"` for exact command grammar. Issue keys are positional for `twg jira workitem get`; do not guess flags, fields, or transition names.

Search results are candidate anchors. Use a native `twg jira workitem get PROJ-123` read to confirm final fields, status, comments, and URLs.

## Safe mutations

- Read current state before every create, update, comment, or transition.
- Before create or update, inspect the required field metadata and provide returned custom field IDs rather than guessed display names.
- Before a transition, discover available transitions rather than guessing one.
- Show the intended mutation to the user before adding `--yes`.
- Verify a completed mutation with a native issue read and report the resulting issue key and URL.

Do not claim Confluence or other Atlassian product coverage.
