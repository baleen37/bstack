---
name: tmux-workers
description: Use when you need to run multiple AI CLI agents (claude, codex, gemini) in parallel on independent subtasks — spawns visible tmux split panes for real-time monitoring
---

# tmux-workers

Spawn AI CLI workers in visible tmux split panes. Fire-and-forget — no blocking, no result collection.

## Agent Commands

| Agent | Command | Notes |
|-------|---------|-------|
| **claude** | `cat "$TASK_FILE" \| claude -p --dangerously-skip-permissions` | pipe task via stdin |
| **codex** | `codex exec --full-auto - < "$TASK_FILE"` | stdin redirect |
| **gemini** | `gemini -p '' --yolo < "$TASK_FILE"` | stdin redirect |

## Spawn Pattern

```bash
# 1. Unique ID & task file
ID="$(date +%s)-$$-1"
TASK_FILE="/tmp/tmux-worker-$ID.txt"
printf '%s' "$TASK" > "$TASK_FILE"

# 2. Split pane & capture pane ID
PANE_ID=$(tmux split-window -h -c "$CWD" -PF '#{pane_id}')

# 3. Send command (pick agent from table above)
tmux send-keys -t "$PANE_ID" -l -- "cat \"$TASK_FILE\" | claude -p --dangerously-skip-permissions; rm -f \"$TASK_FILE\""
tmux send-keys -t "$PANE_ID" Enter

# 4. Done. No waiting.
```

For additional workers, split vertically from the first worker pane:

```bash
PANE_ID2=$(tmux split-window -v -t "$PANE_ID" -c "$CWD" -PF '#{pane_id}')
tmux send-keys -t "$PANE_ID2" -l -- "codex exec --full-auto - < \"$TASK_FILE2\"; rm -f \"$TASK_FILE2\""
tmux send-keys -t "$PANE_ID2" Enter
```

## Layout

```
┌──────────────────┬──────────────────┐
│                  │   Worker 1       │
│   Leader         ├──────────────────┤
│   (current)      │   Worker 2       │
│                  ├──────────────────┤
│                  │   Worker 3       │
└──────────────────┴──────────────────┘
```

- First worker: `split-window -h` (right side)
- Additional workers: `split-window -v -t $FIRST_WORKER_PANE` (stack vertically)
- Track panes by pane ID (e.g., `%3`, `%7`), not index

## Working Directory

```bash
# Option 1: tmux -c flag (preferred)
tmux split-window -h -c "/path/to/project" -PF '#{pane_id}'

# Option 2: codex -C flag
codex exec --full-auto -C /path/to/project - < "$TASK_FILE"
```

## Checking Workers (Optional)

```bash
# List all panes with status
tmux list-panes -F '#{pane_id} #{pane_current_command} #{pane_dead}'

# Preview worker output (replace %3 with actual pane ID)
tmux capture-pane -t %3 -p | tail -10

# Kill a specific worker
tmux kill-pane -t %3
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `codex` instead of `codex exec` | Opens interactive TUI and hangs forever |
| `send-keys` without `-l` flag | Special chars interpreted as tmux keybindings, not literal input |
| Pane index instead of pane ID | Use pane ID (e.g., `%3`) from `-PF '#{pane_id}'` — stable across window switches |
| Task inlined in command string | Special chars and quotes break. Always write to temp file first |
| Missing `-PF` on `split-window` | Cannot capture pane ID for later reference |
| Running outside tmux | Check `$TMUX` env var. If unset, start with `tmux new-session` first |
| claude without `--dangerously-skip-permissions` | Worker stalls at permission prompt with no human to approve |
| More than 4-5 workers in one window | Panes become too small. Use a separate tmux window for overflow |
| Forgetting task file cleanup | Add `; rm -f "$TASK_FILE"` at end of worker command |

## Rules

- Always write `$TASK` to a temp file — never inline in the command
- Always use `send-keys -l --` for literal input, then `send-keys Enter` separately
- Use unique IDs: `$(date +%s)-$$-N` where N is the worker number
- Each worker command should end with `; rm -f "$TASK_FILE"` for cleanup
- If not inside tmux (`$TMUX` unset), create a session first
