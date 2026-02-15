# Handoff Plugin

Session handoff plugin for Claude Code - save and restore session context between sessions.

## Overview

The Handoff plugin enables you to:

- **Pause and resume work**: Save your current session state and pick up where you left off later
- **Context sharing**: Hand off work context to team members on the same project

## Features

- **/handoff command**: Save current session context to a handoff file
- **/pickup [uuid]**: Load a handoff (default: most recent, or specify UUID)
- **/handoff-list**: List all handoffs for the current project
- **Automatic notification**: SessionStart hook notifies you of recent handoffs (within 5 minutes)

## Installation

The plugin is automatically discovered when placed in the `plugins/` directory.

## Usage

### Creating a Handoff

```bash
/handoff
```

This analyzes your current session and creates a handoff file with:

- Session summary
- References (plans, tasks, session IDs)

### Loading a Handoff

```bash
# Load most recent handoff for current project
/pickup

# Load specific handoff
/pickup 550e8400-e29b-41d4-a716-446655440000
```

**Automatic Context Restoration:**

The `/pickup` command automatically loads and displays all referenced context:

- **Plan files**: If `plan_path` is set in the handoff, the plan content is automatically loaded and displayed
- **Tasks session**: If `tasks_session_id` is set, the current tasks list is displayed
- **Source session**: The original session ID is shown (use conversation-memory plugin to search for it)

This gives you complete context restoration without manual file hunting.

### Listing Handoffs

```bash
/handoff-list
```

Shows all handoffs for the current project, sorted by creation date.

## Handoff Data Structure

Handoff files are stored as JSON in `~/.claude/handoffs/{UUID}.json`:

```json
{
  "id": "uuid-v4",
  "created_at": "2026-02-05T00:00:00Z",
  "loaded_at": null,
  "project_name": "project-name",
  "project_path": "/path/to/project",
  "branch": "feature-branch",
  "summary": "Brief summary of current work",
  "references": {
    "plan_path": "~/.claude/plans/plan-name.md",
    "tasks_session_id": "session-uuid"
  },
  "source_session_id": "current-session-uuid"
}
```

## Constraints

- **Project-specific**: Handoffs are filtered by project path
- **Reference-based**: References to plans/tasks/sessions are stored, not content
- **UUID-based**: Each handoff has a unique UUID for identification

## SessionStart Hook

When you start a new session, the plugin checks for:

- Handoffs created within the last 5 minutes
- Handoffs that haven't been loaded yet
- Handoffs for the current project

If found, you'll see a notification:

```text
Handoff: Recent handoff found. Use /pickup to resume: [summary]
```

## Examples

### Workflow 1: Pause and Resume

```bash
# End of day - save current work
/handoff
# Output: Handoff saved with ID: 550e8400-e29b-41d4-a716-446655440000

# Next day - resume work
/pickup
# Output:
# Loading handoff session: Implementing handoff plugin
#
# Handoff ID: 550e8400-e29b-41d4-a716-446655440000
# Created: 2026-02-05 00:00:00 UTC
# Project: claude-plugins (feat/create-handoff)
#
# Summary:
# Implementing handoff plugin for session context transfer
#
# ---
#
# ### Referenced Plan
# ### Implementation Plan for Handoff Plugin
# [Full plan content auto-loaded here]
#
# ---
#
# ### Tasks Session
# Session: 75c272b1-b00d-4bbb-bfa5-87269f30ff47
#
# [pending] Complete /pickup command implementation
# [in_progress] Add tests for all commands
#
# ---
#
# ### Source Session
# Session ID: 00538c2c-c67e-4afe-a933-bb8ed6ed19c6
```

### Workflow 2: Team Handoff

```bash
# Developer A finishes their work
/handoff
# Output: Handoff saved with ID: 550e8400-e29b-41d4-a716-446655440000

# Developer B picks up the work
/handoff-list  # See available handoffs
/pickup 550e8400-e29b-41d4-a716-446655440000  # Load specific handoff
# Output: Full context restored with plan and tasks
```

## Testing

Run the test suite:

```bash
bats tests/handoff/handoff.bats
```

## Requirements

- `jq` for JSON processing
- `uuidgen` for UUID generation (or use alternative)
- Bash shell

## License

MIT
