---
description: "Cancel active Ralph loop"
allowed-tools: ["Bash(kill*)", "Bash(cat .ralph/ralph.pid)", "Bash(rm .ralph/ralph.pid)"]
---

# Cancel Ralph

Cancel the active Ralph loop by killing the ralph.sh process.

1. Check if `.ralph/ralph.pid` exists
2. If not found: report "No active Ralph loop"
3. If found:
   - Read the PID from the file
   - Kill the process
   - Remove the PID file
   - Report cancellation
