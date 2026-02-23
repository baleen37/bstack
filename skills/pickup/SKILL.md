---
name: pickup
description: Use when starting a session that continues prior work — finds and loads the latest handoff document
---

Find the most recent handoff document and resume work from where it left off.

## Steps

1. Find the latest file in `.claude/handoffs/` (sorted by filename = sorted by time)
   - If an argument is provided, use that file path instead
   - If no handoffs exist, tell the user and stop
2. Read the handoff document
3. Check freshness: compare the handoff's commit hash against current HEAD
   - Same: proceed directly
   - Different: report how many commits since, show `git log --oneline` between the two,
     and flag anything that may conflict with Next Steps
4. Read the Key Files listed in the handoff
5. Summarize the situation to the user: goal, current state, and proposed first action from Next Steps
6. Begin working on the first Next Step
