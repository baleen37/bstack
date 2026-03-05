#!/usr/bin/env bash
set -euo pipefail

# dispatch <tool> "task"
# Dispatch a task to an AI CLI tool via tmux.
# Tools: claude, codex, gemini

die() { echo "Error: $*" >&2; exit 1; }

[[ $# -ge 2 ]] || die "Usage: dispatch <claude|codex|gemini> \"task\""

TOOL="$1"
TASK="$2"

case "$TOOL" in
    claude|codex|gemini) ;;
    *) die "Unknown tool: $TOOL (supported: claude, codex, gemini)" ;;
esac

BINARY="$(command -v "$TOOL" 2>/dev/null)" || die "$TOOL not found in PATH"

ID="dispatch-$(date +%s)-$$"
TASK_FILE="/tmp/${ID}-task.txt"
RESULT="/tmp/${ID}-result.md"

# Write task to file (safe quoting)
printf '%s' "$TASK" > "$TASK_FILE"

# Build tool-specific command
case "$TOOL" in
    claude)  CMD="$BINARY -p \"\$(cat '$TASK_FILE')\" --dangerously-skip-permissions > '$RESULT'" ;;
    codex)   CMD="$BINARY --full-auto -o '$RESULT' \"\$(cat '$TASK_FILE')\"" ;;
    gemini)  CMD="$BINARY -p \"\$(cat '$TASK_FILE')\" --yolo > '$RESULT'" ;;
esac

command -v tmux &>/dev/null || die "tmux not found"

cleanup() {
    tmux kill-session -t "$ID" 2>/dev/null || true
    rm -f "$TASK_FILE" "$RESULT"
}
trap cleanup EXIT

tmux new-session -d -s "$ID" -x 220 -y 50
tmux send-keys -t "$ID" -l -- "$CMD && tmux wait-for -S $ID"
tmux send-keys -t "$ID" Enter

timeout 300 tmux wait-for "$ID" || { echo "Timeout" >&2; exit 124; }

[[ -s "$RESULT" ]] && cat "$RESULT"
