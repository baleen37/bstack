---
name: remembering-conversations
description: This skill should be used when the user asks "how should I...", "what's the best approach...", "do you remember...", "why did we...", mentions "last time", "before", "we discussed", or when stuck after investigation. Searches conversation history using claude-mem 3-layer workflow.
version: 0.3.0
---

# Remembering Conversations

Search conversation history to find past decisions, patterns, and failed approaches before reinventing.

## Core Principle

**Search before reinventing.** Searching costs nothing; reinventing or repeating mistakes costs everything.

## When to Use

**After understanding the task:**

- User asks "how should I..." or "what's the best approach..."
- After exploring codebase, need to make architectural decisions

**When stuck:**

- Investigated a problem, can't find solution
- Need to follow unfamiliar workflow

**Historical signals:**

- User says "last time", "before", "we discussed"
- User asks "why did we...", "do you remember..."

**Don't search first:**

- For current codebase structure (use Grep/Read)
- For info in current conversation
- Before understanding the task

## 3-Layer Workflow

**ALWAYS follow this workflow to save 10x tokens:**

### 1. Search for Index

`mcp__plugin_claude-mem_mcp-search__search`

- Get lightweight index with observation IDs
- Params: `query`, `limit`, `dateStart`, `dateEnd`

### 2. Get Context

`mcp__plugin_claude-mem_mcp-search__timeline`

- Get context around interesting results
- Params: `query` or `anchor`, `depth_before`, `depth_after`

### 3. Fetch Details

`mcp__plugin_claude-mem_mcp-search__get_observations`

- Fetch ONLY filtered IDs from steps 1-2
- Params: `ids` (required array)

**NEVER fetch full details without filtering first.**

## Strategy

1. Search broad: `{ query: "authentication" }`
2. Review index results
3. Get timeline context for interesting IDs
4. Fetch full details for most relevant observations
5. Synthesize: key insights, apply to context, recommend approach

## Extract

- Past decisions and rationale
- Failed approaches and why
- Successful patterns
- Gotchas and edge cases
