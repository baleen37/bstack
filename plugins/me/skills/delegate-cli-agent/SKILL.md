---
name: delegate-cli-agent
description: Use when you need to run Codex or Gemini on a subtask and wait for the result — launches in a detached tmux session and blocks until completion
---

# Delegate CLI Agent

Delegate a task to an AI CLI tool in a detached tmux session and block until completion — no polling.

## Supported Tools

| Tool | Non-interactive command | Result capture | Notes |
|------|------------------------|----------------|-------|
| **Codex** | `codex exec --full-auto` | `-o FILE` flag | Saves final message only (clean text) |
| **Gemini** | `gemini -p "..." --yolo` | `> FILE` redirect | Saves response text; use `-o json` for structured output with `response` field |

## Core Pattern

```bash
ID="$(date +%s)-$$"
SESSION="dispatch-$ID"
RESULT="/tmp/dispatch-$ID.md"
TASK_FILE="/tmp/task-$ID.txt"

# 1. Write task to file (never inline — special chars break shell parsing)
printf '%s' "$TASK" > "$TASK_FILE"

# 2. Launch AI CLI in detached tmux session (pick command from Codex/Gemini sections)
tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" -l -- "<AI_COMMAND using $TASK_FILE>; tmux wait-for -S $ID"
tmux send-keys -t "$SESSION" Enter

# 3. Block until AI signals completion (no polling)
tmux wait-for "$ID"

# 4. Read result (check for failure first)
[[ -s "$RESULT" ]] || { echo "Delegate failed or produced no output" >&2; exit 1; }
cat "$RESULT"

# 5. Cleanup
tmux kill-session -t "$SESSION" 2>/dev/null
rm -f "$RESULT" "$TASK_FILE"
```

## Codex

OpenAI Codex CLI. 코드 수정/생성 작업에 특화. `codex exec`은 작업 완료 후 자동 종료.

```bash
ID="$(date +%s)-$$"
SESSION="dispatch-$ID"
RESULT="/tmp/dispatch-$ID.md"
TASK_FILE="/tmp/task-$ID.txt"

printf '%s' "$TASK" > "$TASK_FILE"

tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" -l -- "codex exec --full-auto -o \"$RESULT\" - < \"$TASK_FILE\"; tmux wait-for -S $ID"
tmux send-keys -t "$SESSION" Enter

tmux wait-for "$ID"
[[ -s "$RESULT" ]] || { echo "Codex failed" >&2; exit 1; }
cat "$RESULT"
tmux kill-session -t "$SESSION" 2>/dev/null
rm -f "$RESULT" "$TASK_FILE"
```

| Flag | Purpose |
|------|---------|
| `codex exec` | Non-interactive mode — `codex` alone opens TUI and never exits |
| `--full-auto` | Auto-approve all shell commands (`workspace-write` sandbox) |
| `-o FILE` | Write final response text to file (clean, no ANSI codes) |
| `--skip-git-repo-check` | Required outside a git repository |
| `-C DIR` | Set working directory (alternative to `cd` in the command) |

## Gemini

Google Gemini CLI. 코드 작업 외 리서치/분석 등 범용 작업에 적합. `-p` 플래그로 비대화형 실행.

```bash
ID="$(date +%s)-$$"
SESSION="dispatch-$ID"
RESULT="/tmp/dispatch-$ID.md"
TASK_FILE="/tmp/task-$ID.txt"

printf '%s' "$TASK" > "$TASK_FILE"

tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" -l -- "gemini -p '' --yolo < \"$TASK_FILE\" > \"$RESULT\"; tmux wait-for -S $ID"
tmux send-keys -t "$SESSION" Enter

tmux wait-for "$ID"
[[ -s "$RESULT" ]] || { echo "Gemini failed" >&2; exit 1; }
cat "$RESULT"
tmux kill-session -t "$SESSION" 2>/dev/null
rm -f "$RESULT" "$TASK_FILE"
```

| Flag | Purpose |
|------|---------|
| `-p "PROMPT"` | Non-interactive (headless) mode with prompt |
| `--yolo` | Auto-approve all tool actions |
| `> FILE` | Redirect response text to file |
| `-o json > FILE` | Structured output — result in `.response` field, includes token stats |

**`-o json` 사용 시 결과 추출:**
```bash
RESPONSE=$(jq -r '.response' "$RESULT")
```

## Rules

- Use `;` not `&&` before `tmux wait-for -S` — `&&` causes permanent hang if the AI exits with non-zero. `;` always signals; detect failure via `[[ -s "$RESULT" ]]`.
- Use `send-keys -l --` for literal input — prevents special characters (`"`, `$`, `>`) from being interpreted as tmux key bindings.
- Use unique IDs: `$(date +%s)-$$` prevents session name collisions.
- Always check result file is non-empty before reading: `[[ -s "$RESULT" ]]`.
- Always kill the session and remove the result file after reading.
- **Always write `$TASK` to a temp file** — never inline it in the command. Special characters, quotes, and newlines will break shell parsing otherwise:
  ```bash
  TASK_FILE="/tmp/task-$ID.txt"
  printf '%s' "$TASK" > "$TASK_FILE"
  # Codex: codex exec --full-auto -o "$RESULT" - < "$TASK_FILE"
  # Gemini: gemini -p '' --yolo < "$TASK_FILE" > "$RESULT"
  # Cleanup: rm -f "$RESULT" "$TASK_FILE"
  ```

## Working Directory

Dispatched CLI inherits the tmux session's cwd. To specify:

```bash
tmux send-keys -t "$SESSION" -l -- "cd /path/to/project && <AI_COMMAND>; tmux wait-for -S $ID"
tmux send-keys -t "$SESSION" Enter
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `codex` instead of `codex exec` | Opens interactive TUI and hangs |
| `&&` instead of `;` before signal | AI failure → no signal → hangs forever |
| Missing `send-keys -l` flag | Special chars interpreted as tmux keybindings |
| `cat "$RESULT"` without `-s` check | Silently outputs nothing on AI failure |
| Reusing session names | Use unique ID per call |
| Forgetting cleanup | Sessions accumulate; always `tmux kill-session` after reading |
| Codex outside git repo | Add `--skip-git-repo-check` |
| Inlining `$TASK` in the command string | Always write to temp file; use stdin (`-` or `< FILE`) |
