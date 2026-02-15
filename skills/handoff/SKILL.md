---
name: handoff
description: Save current session context to a handoff file for later restoration. Use when the user asks to "save session", "create a handoff", "save context", "pause work", or wants to prepare for a fresh conversation.
---

# Handoff

## Overview

Write or update `HANDOFF.md` in the project root so the next agent (or yourself in a fresh session) can continue work without losing context.

A good handoff is the difference between "pick up where we left off" and "start over from scratch." Capture the hard-won knowledge — failed approaches, implicit decisions, environmental quirks — not just a status update.

## When to Use

- Session is getting long and context window is filling up
- Switching to a different task and want to preserve state
- Ending a work session for the day
- Before a conversation reset or tool restart
- When the user says "save", "handoff", "pause", "park this"

## Process

1. **Check for existing `HANDOFF.md`** — if it exists, read it first. Preserve anything still relevant.
2. **Assess current state** — review recent conversation, open files, git status, task list
3. **Write `HANDOFF.md`** using the template below
4. **Tell the user** the file path and suggest they reference it when starting a new session

## What to Capture

### Must Include

- **Goal**: What are we trying to accomplish? Not just "fix bug" but the actual problem and desired outcome.
- **Current state**: What's done, what's in progress, what's left. Include branch name and whether there are uncommitted changes.
- **Key decisions**: Architectural choices, trade-offs made, constraints discovered. These are the hardest to reconstruct.
- **Failed approaches**: What was tried and why it didn't work. This prevents the next session from repeating mistakes.
- **Next steps**: Concrete, actionable items. "Fix the tests" is bad. "Fix `test_auth_flow` — fails because the mock doesn't handle the new token format from commit abc123" is good.

### Must NOT Include

- Full conversation transcripts or lengthy explanations
- Code snippets that exist in the repo (reference file:line instead)
- Speculative future work beyond the immediate task
- Information already in CLAUDE.md or project docs

## Template

```markdown
# Handoff

**Branch:** `feature/xyz`
**Last commit:** `abc1234 - description`
**Uncommitted changes:** yes/no (describe if yes)

## Goal

[What we're trying to accomplish and why]

## Current State

[What's done, what's in progress. Be specific about file paths and line numbers.]

## Key Decisions

[Architectural choices, trade-offs, constraints discovered during this session]

## Failed Approaches

[What was tried and why it didn't work — prevents repeating mistakes]

## Next Steps

1. [Concrete action item with enough context to execute]
2. [Another action item]
```

## Red Flags

| Behavior | Problem |
|----------|---------|
| Writing vague next steps like "continue work" | Next session won't know what to do |
| Omitting failed approaches | Next session will repeat the same mistakes |
| Including full code blocks | Reference files instead — code changes between sessions |
| Skipping git state | Next session needs to know about uncommitted work |
| Overwriting existing HANDOFF.md without reading it | Prior context may still be relevant |
