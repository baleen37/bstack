---
name: knowledge-base
description: Use when a user asks to search, retrieve, or check the status of private personal or organization Markdown knowledge.
---

# Knowledge Base

Use the read-only `status`, `search`, and `get` tools for private Markdown knowledge.

1. If index readiness is unknown, call `status` first.
2. Call `search` before `get`; pass a focused query and then retrieve only the relevant canonical reference.
3. Set `scope` to `personal` or `wooto` when the request is limited to one source. Omit `scope` to search both.
4. Cite the canonical qmd URI returned by the tools in the answer.

Do not treat `scope` as an authorization boundary. Do not use this plugin to edit, commit, or
push documents. Only explain setup, sync, or index operations when the user explicitly requests
them.
