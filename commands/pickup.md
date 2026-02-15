---
name: pickup
description: Load a handoff session to restore context from a previous session with automatic reference resolution
argument-hint: "[uuid]"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pickup.sh)"]
---

# Pickup Handoff

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/pickup.sh" ${ARGUMENTS}
```
