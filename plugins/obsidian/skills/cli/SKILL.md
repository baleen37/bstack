---
name: cli
description: Use when the user asks to interact with their Obsidian vault — opening notes, searching, creating, appending, or any other vault operation
---

# Obsidian CLI

Interact with the user's Obsidian vault using the `obsidian` CLI.

**Prerequisite:** Obsidian app must be running. `obsidian` must be on PATH (enabled in Obsidian Settings → CLI).

## Workflow

1. **Understand** what the user wants to do
2. **Look up** the right command if unsure: `obsidian help <command>`
3. **Execute** with the Bash tool
4. **Present** results clearly — don't just dump raw output

## Tips

- Names are fuzzy-matched by default — no need for exact file paths
- Use `vault=<name>` to target a specific vault
- Use `format=json` for structured output when you need to parse results
- Run `obsidian help` to see all available commands
- Run `obsidian help <command>` to see options for a specific command
