---
name: ralph-cancel
description: Cancel an active Ralph loop — cleans up state files and exits the persistence loop
---

# Ralph Cancel

Cancel the active Ralph loop for the current project.

## Steps

1. Check if `.ralph/state/ralph-state.json` exists
   - If it does not exist, report: "No active Ralph loop found."
   - If it exists, read it to confirm `active: true`
   - If `active: false`, report: "Ralph loop is already inactive."

2. Write `.ralph/state/cancel-signal-state.json` with content `{}`

3. Update `.ralph/state/ralph-state.json`: set `active: false`

4. Report: "Ralph loop cancelled."

The Stop hook will detect the cancel signal on the next iteration and exit cleanly.
