---
name: handoff
description: This skill should be used when the user asks to "save session", "create a handoff", "save current context", "pause work", or wants to restore a previous session with "pickup", "restore session", "load handoff".
---

# Handoff

Write or update a handoff document so the next agent with fresh context can continue this work.

## Steps

1. Check if `HANDOFF.md` already exists in the project
2. If it exists, read it first to understand prior context before updating
3. Create or update the document with:
   - **Goal**: What we're trying to accomplish
   - **Current Progress**: What's been done so far
   - **What Worked**: Approaches that succeeded
   - **What Didn't Work**: Approaches that failed (so they're not repeated)
   - **Next Steps**: Clear action items for continuing
4. Save as `HANDOFF.md` in the project root
5. Tell the user the file path so they can start a fresh conversation with just that path

## Template

```markdown
# Handoff

## Goal
[What we're trying to accomplish]

## Current Progress
[What's been done so far]

## What Worked
[Approaches that succeeded]

## What Didn't Work
[Approaches that failed - so they're not repeated]

## Next Steps
[Clear action items for continuing]
```
