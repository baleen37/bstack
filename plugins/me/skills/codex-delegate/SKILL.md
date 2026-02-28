---
name: codex-delegate
description: Use when delegating a subtask to OpenAI Codex CLI via tmux - fire-and-wait pattern using tmux wait-for for non-polling completion detection
---

# Codex Delegate

Delegate a task to Codex CLI in a detached tmux session and block until completion — no polling.

## Pattern

```bash
ID="$(date +%s)-$$"
SESSION="codex-$ID"
RESULT="/tmp/codex-$ID.md"

# 1. Launch Codex in detached tmux session
tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" \
  "codex exec --full-auto -o \"$RESULT\" \"$TASK\" && tmux wait-for -S $ID" \
  Enter

# 2. Block until Codex signals completion (no polling)
tmux wait-for "$ID"

# 3. Read result
cat "$RESULT"

# 4. Cleanup
tmux kill-session -t "$SESSION" 2>/dev/null
rm -f "$RESULT"
```

## Key Flags

| Flag | Purpose |
|------|---------|
| `codex exec` | Non-interactive mode (not `codex` alone — that opens interactive TUI) |
| `--full-auto` | Auto-approve all actions (`workspace-write` sandbox, no prompts) |
| `--skip-git-repo-check` | Required when running outside a git repository |
| `-o FILE` | Write Codex's final message to file |
| `tmux wait-for -S ID` | Signal sent by Codex process on exit |
| `tmux wait-for ID` | Claude blocks here until signal arrives |

## Rules

- Use `&&` not `;` between `codex exec` and `tmux wait-for -S` — if Codex fails, no signal is sent and `tmux wait-for` blocks forever. Use a timeout wrapper or handle separately.
- Use unique IDs per invocation: `$(date +%s)-$$` avoids session name collisions when running multiple delegations.
- `tmux wait-for` has no built-in timeout. Wrap with a background killer if needed:
  ```bash
  (sleep 300 && tmux wait-for -S "$ID") &
  tmux wait-for "$ID"
  ```
- Always kill the session and remove the result file after reading.

## Working Directory

Codex inherits the tmux session's working directory. To run in a specific dir:

```bash
tmux send-keys -t "$SESSION" \
  "cd /path/to/project && codex exec --full-auto -o \"$RESULT\" \"$TASK\" && tmux wait-for -S $ID" \
  Enter
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using `codex` instead of `codex exec` | `codex` alone opens interactive TUI and hangs |
| Using `;` instead of `&&` before signal | Codex failure → signal still sent → false completion |
| Reusing session names | Use unique ID per call |
| Forgetting to kill session | Sessions accumulate; use `tmux kill-session` after reading result |
| Running outside git repo | Add `--skip-git-repo-check` flag or Codex will refuse to run |
