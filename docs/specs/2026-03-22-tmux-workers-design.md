# tmux-workers Skill Design

**Date:** 2026-03-22
**Status:** Implemented

## Overview

`tmux-workers` is a skill that spawns multiple AI CLI workers (claude, codex, gemini) in visible tmux split panes for parallel task execution. It replaces the previous `delegate-cli-agent` skill, which only supported a single worker in a detached session with blocking semantics.

## Goals

- Spawn 1-N AI CLI workers in visible tmux split panes
- Support claude, codex, and gemini CLI agents
- Fire-and-forget execution — no blocking, no result file collection
- Provide a consistent pane layout (leader left, workers stacked right)

## Architecture

### Execution Model

Fire-and-forget: the skill spawns workers and returns immediately. Workers run independently in visible panes. No heartbeat, watchdog, or file-based messaging.

### Agent Commands

| Agent | Non-interactive Command |
|-------|------------------------|
| claude | `cat "$TASK_FILE" \| claude -p --dangerously-skip-permissions` |
| codex | `codex exec --full-auto - < "$TASK_FILE"` |
| gemini | `gemini -p '' --yolo < "$TASK_FILE"` |

### Pane Layout

```
┌──────────────────┬──────────────────┐
│                  │   Worker 1       │
│   Leader         ├──────────────────┤
│   (current)      │   Worker 2       │
│                  ├──────────────────┤
│                  │   Worker 3       │
└──────────────────┴──────────────────┘
```

- First worker: `tmux split-window -h` (horizontal split, creates right side)
- Additional workers: `tmux split-window -v -t $FIRST_WORKER_PANE` (vertical stack within right side)
- Pane identification via `%N` format (stable across window switches)

### Spawn Pattern

1. Generate unique ID: `$(date +%s)-$$-N`
2. Write task to temp file: `printf '%s' "$TASK" > "$TASK_FILE"`
3. Create split pane with ID capture: `tmux split-window -h -c "$CWD" -PF '#{pane_id}'`
4. Send command via literal keys: `tmux send-keys -t "$PANE_ID" -l -- "<CMD>; rm -f \"$TASK_FILE\""`
5. No waiting — done

### Key Design Decisions

1. **Fire-and-forget over blocking**: Workers run independently. The user watches output in real-time via split panes. No need for result files or `tmux wait-for`.

2. **Split pane over detached session**: Provides real-time visibility. Inspired by oh-my-claudecode's `omc team` CLI which uses the same pattern.

3. **Task file pattern**: Tasks are always written to temp files, never inlined in commands. This prevents special character and quote escaping issues.

4. **`--dangerously-skip-permissions` for claude**: Required for fire-and-forget since no human is watching each pane to approve permissions.

## What Changed from delegate-cli-agent

| Aspect | delegate-cli-agent | tmux-workers |
|--------|-------------------|--------------|
| Worker count | 1 | N |
| Execution | Detached session, blocking | Split pane, fire-and-forget |
| Result collection | File-based (`-o FILE`, `> FILE`) | None (view in pane) |
| Agent support | codex, gemini | claude, codex, gemini |
| Visibility | Hidden (detached) | Visible (split panes) |

## Files

| File | Purpose |
|------|---------|
| `plugins/me/skills/tmux-workers/SKILL.md` | Skill document |
| `tests/skills/test_tmux_workers_skill.bats` | BATS structure tests |

## Inspiration

Based on [oh-my-claudecode](https://github.com/yeachan-heo/oh-my-claudecode)'s `omc team` CLI, which spawns real claude/codex/gemini processes in tmux split-panes with on-demand spawn and auto-cleanup. This skill takes the core spawning pattern while omitting the complex orchestration layer (heartbeat, watchdog, file-based messaging, atomic locking).
