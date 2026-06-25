---
name: delegating-tool-calls
description: Use when a task needs many tool/MCP/CLI calls, large or repeated results, or aggregation across sources — before calling tools directly in the main thread. Symptoms: about to loop tool calls, dump raw JSON into context, or answer "list all / how many" from one unpaginated response.
---

# Delegating Tool Calls

The principle is **keep raw tool results out of your context** — process them with code or CLI
and surface only the answer. Two separate decisions:

- **How to process** (always): pipe results through code/`jq`, not into your reasoning.
- **Whether to delegate** (only when heavy): hand the job to a subagent so its exploration and
  raw output stay out of the *main* thread too.

> **Not the API's "Programmatic Tool Calling."** Claude Code has no PTC; MCP connector tools
> can't be called from code. This is a Claude Code pattern.

## Whether to delegate

| Situation | Do |
| --- | --- |
| 1–2 simple reads, or one `pup … \| jq` line | Run directly in the main thread — the pipe already isolates raw data |
| A "list all / how many / every" answer that spans more than one page (you follow a `nextPageToken`/`--page`/cursor) | Delegate the whole pagination loop **from the first call** — don't absorb a page or two yourself first |
| Heavy aggregation, many calls, exploratory back-and-forth | Delegate to a subagent |
| Either way | Process with code/`jq`; never dump raw JSON into context |

A "list all / how many / find every" question is where partial responses bite (below) — that
risk applies *wherever* you run it, delegated or not.

> When results come back as **MCP tool output** (not stdout) you can't pipe them through `jq`,
> and a `fields`/projection argument is a *request the server may ignore* — so trimming the
> request is not a reliable substitute for isolating the loop in a subagent.

## The one failure that matters: partial responses answered as if complete

`list`/`search`/`query` tools return a **truncated page by default**. Answering "how many" or
"list all" from a single response gives a **silently wrong answer** — no error, just incomplete.

Observed: the same "how many monitors are muted?" returned **30** (saw page 1 of 200) vs **56**
(saw all pages). Both looked confident; one was wrong.

**Before answering a total/all question:**

1. Check whether the response is capped — look for `metadata.count`, a default limit, or
   `--limit`/`--page`/`--per-page` flags (`<tool> --help`).
2. If capped, paginate to completion, OR state explicitly that the answer covers only the page seen.
3. Never present a partial set as the whole.

## How to call (either mode)

Pick by how the target is exposed (`claude mcp list`, `command -v`):

| Exposed as | Call it by | Notes |
| --- | --- | --- |
| **CLI** (`pup`, `ks`, `gh`) | Bash + `--output json \| jq` | Keep raw in the pipe; surface only the filtered result |
| **MCP stdio** (local, e.g. `npx ...`) | **copy** `reference/mcp-stdio-client.mjs`, don't re-derive | zero-dep, verified handshake + `protocolVersion` — re-deriving wastes a round-trip and guesses the version |
| **MCP remote OAuth** (`https://…/mcp`) | the MCP tool directly | shell can't borrow its auth |
| **REST** (token in hand) | `curl \| jq` | — |

## Other rules

- **Verify names AND argument keys, don't guess.** Inspect shape first (`jq '.data[0] | keys'`),
  and for MCP read each tool's `inputSchema` from `tools/list` — argument keys are guessed just as often as tool names.
- **JSON, not table.** `pup`'s table formatter panics on Korean multibyte text; `--output json` is pipeable.
- **`--no-agent`** for scripts the user runs outside the session — some CLIs wrap output in an agent-mode envelope.

## Dispatch template (when delegating)

> Find all X. Return ONLY: the count, the names, and the exact filter you used.
> Use `--output json | jq`; keep raw data in the pipe, not your reasoning; inspect the JSON
> shape before naming fields; **confirm the response isn't paginated/capped before reporting a
> total** — paginate or say it's partial. Don't return raw JSON.
