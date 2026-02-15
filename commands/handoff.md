---
name: handoff
description: Save current session context to a handoff file for later restoration
argument-hint: ""
allowed-tools: Bash(*)
---

# Save Handoff

Analyze the conversation and extract a brief summary (2-3 sentences) of what was being worked on.

Then execute the handoff script with the generated summary:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/handoff.sh" "Summary of what was being worked on..."
```

Inform the user of the handoff ID and how to restore it.
