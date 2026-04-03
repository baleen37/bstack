---
name: ralph-cancel
description: Cancel an active Ralph loop — cleans up state files and exits the persistence loop
---

# Ralph Cancel

Cancel the Ralph loop in the current project (CWD).

1. If `.ralph/state/ralph-state.json` missing → "No active Ralph loop found."
2. If `active: false` → "Ralph loop is already inactive."
3. Write `.ralph/state/cancel-signal-state.json` (`{}`) — the Stop hook detects this and exits
4. Set `active: false` in `.ralph/state/ralph-state.json`
5. Report: "Ralph loop cancelled."
