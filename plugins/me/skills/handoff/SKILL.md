---
name: handoff
description: Use when ending a session and work needs to continue in a fresh conversation
---

Write a handoff document so the next agent with fresh context can continue this work.

## Steps

1. Collect git state: branch name, HEAD commit (short hash), count of dirty files
2. Ensure `.claude/handoffs/` directory exists
3. Generate filename: `YYYY-MM-DD-HHMMSS-<slug>.md` where slug summarizes the work (e.g., `auth-refactor`, `fix-login-bug`)
4. If previous handoffs exist in `.claude/handoffs/`, read the most recent one for continuity
5. Write the document using the template below
6. Tell the user the file path so they can start a fresh conversation with `/pickup`

## Template

```markdown
# Handoff: <brief title>

- **Branch**: <current branch>
- **Commit**: <short hash>
- **Dirty files**: <count>

## Goal
What we're trying to accomplish.

## Current State
What's done, what's in progress. Be specific.

## What Worked
Approaches that succeeded.

## What Didn't Work
Approaches that failed — so they're not repeated.

## Key Files
- path/to/file.ts:45-67 - why this matters
- path/to/test.ts - related test

## Decisions Made
- Decision and its rationale

## Open Questions
- OPEN: Unresolved question needing human input
- ASSUMED: Assumption made without confirmation

## Next Steps
1. First priority — specific enough to act on without extra context
2. Second priority
```

## Rules

- Use `file:line` references, not code snippets — saves tokens, stays current
- Next Steps must be actionable without reading the design doc — if context is needed, inline it
- Mark assumptions explicitly with ASSUMED label
- Never include secrets, API keys, or credentials
