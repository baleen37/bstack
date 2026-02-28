---
name: dispatch
description: Use when delegating a subtask to an AI CLI tool (Codex, Gemini, OpenCode, etc.) via tmux - fire-and-wait pattern using tmux wait-for for non-polling completion detection
---

# Dispatch

Dispatch a task to an AI CLI tool in a detached tmux session and block until completion — no polling.

## Supported Tools

| Tool | Non-interactive command | Result capture | Notes |
|------|------------------------|----------------|-------|
| **Codex** | `codex exec --full-auto` | `-o FILE` flag | Saves final message only (clean text) |
| **Gemini** | `gemini -p "..." --yolo` | `> FILE` redirect | Saves response text; use `-o json` for structured output with `response` field |
| **OpenCode** | TBD | TBD | |

## Core Pattern

```bash
ID="$(date +%s)-$$"
SESSION="dispatch-$ID"
RESULT="/tmp/dispatch-$ID.md"

# 1. Launch AI CLI in detached tmux session (pick command from table above)
tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" \
  "<AI_COMMAND> && tmux wait-for -S $ID" \
  Enter

# 2. Block until AI signals completion (no polling)
tmux wait-for "$ID"

# 3. Read result
cat "$RESULT"

# 4. Cleanup
tmux kill-session -t "$SESSION" 2>/dev/null
rm -f "$RESULT"
```

## Codex

OpenAI Codex CLI. 코드 수정/생성 작업에 특화. `codex exec`은 작업 완료 후 자동 종료.

```bash
ID="$(date +%s)-$$"
SESSION="dispatch-$ID"
RESULT="/tmp/dispatch-$ID.md"

tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" \
  "codex exec --full-auto -o \"$RESULT\" \"$TASK\" && tmux wait-for -S $ID" \
  Enter

tmux wait-for "$ID"
cat "$RESULT"
tmux kill-session -t "$SESSION" 2>/dev/null
rm -f "$RESULT"
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

tmux new-session -d -s "$SESSION" -x 220 -y 50
tmux send-keys -t "$SESSION" \
  "gemini -p \"$TASK\" --yolo > \"$RESULT\" && tmux wait-for -S $ID" \
  Enter

tmux wait-for "$ID"
cat "$RESULT"
tmux kill-session -t "$SESSION" 2>/dev/null
rm -f "$RESULT"
```

| Flag | Purpose |
|------|---------|
| `-p "PROMPT"` | Non-interactive (headless) mode with prompt |
| `--yolo` | Auto-approve all tool actions |
| `> FILE` | Redirect response text to file |
| `-o json > FILE` | Structured output — result in `.response` field, includes token stats |

**`-o json` 사용 시 결과 추출:**
```bash
RESPONSE=$(cat "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])")
```

## Rules

- Use `&&` not `;` before `tmux wait-for -S` — on failure, no signal → `tmux wait-for` blocks forever.
- Use unique IDs: `$(date +%s)-$$` prevents session name collisions.
- `tmux wait-for` has no built-in timeout. Add a background killer if needed:
  ```bash
  (sleep 300 && tmux wait-for -S "$ID") &
  tmux wait-for "$ID"
  ```
- Always kill the session and remove the result file after reading.

## Working Directory

Dispatched CLI inherits the tmux session's cwd. To specify:

```bash
tmux send-keys -t "$SESSION" \
  "cd /path/to/project && <AI_COMMAND> && tmux wait-for -S $ID" \
  Enter
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `codex` instead of `codex exec` | Opens interactive TUI and hangs |
| `;` instead of `&&` before signal | AI failure → signal still fires → false completion |
| Reusing session names | Use unique ID per call |
| Forgetting cleanup | Sessions accumulate; always `tmux kill-session` after reading |
| Codex outside git repo | Add `--skip-git-repo-check` |
