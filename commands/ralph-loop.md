---
description: "Start Ralph loop in current session"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ralph.sh*)"]
---

# Ralph Loop

Execute the Ralph loop script. This will spawn fresh Claude instances in a bash loop.

## Prerequisites

- `.ralph/prd.json` must exist (run `/ralph-init` first)

## Usage

Default (10 iterations):

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/ralph.sh"
```

With custom max iterations:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/ralph.sh" $ARGUMENTS
```

## What Happens

1. Script reads `.ralph/prd.json` for user stories
2. For each iteration, spawns a fresh `claude --print` instance
3. Each instance implements one user story, runs tests, commits if passing
4. Loop exits when all stories pass or max iterations reached
5. Progress is tracked in `.ralph/progress.txt`

## Monitoring

Watch progress in another terminal:

```bash
tail -f .ralph/progress.txt
```

To cancel: `/cancel-ralph`
