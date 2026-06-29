---
name: notion-search
description: Search Notion workspace content through the official Notion MCP server.
---

# Notion Search

Use the official Notion MCP server configured by this plugin.

## Workflow

1. Identify the workspace area, topic, page, or database before searching.
2. Search existing pages and database rows before assuming content is absent.
3. Fetch relevant source pages before summarizing; do not rely on snippets alone.
4. Preserve page links when reporting findings.
5. Separate Notion evidence from your own interpretation.

## Safety

- Missing results may mean missing permissions.
- Keep private workspace content scoped to the user's request.
- Avoid quoting large pages verbatim.
