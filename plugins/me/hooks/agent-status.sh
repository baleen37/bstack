#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TMUX_PANE:-}" ]] || ! command -v tmux >/dev/null 2>&1; then
    exit 0
fi

event="$(jq -r '.hook_event_name // empty' 2>/dev/null)" || exit 0

case "$event" in
    SessionStart | Stop)
        state="ready"
        ;;
    UserPromptSubmit)
        state="running"
        ;;
    PermissionRequest)
        state="needs_input"
        ;;
    SessionEnd)
        tmux set-option -pu -t "$TMUX_PANE" @agent_status >/dev/null 2>&1 || true
        tmux refresh-client -S >/dev/null 2>&1 || true
        exit 0
        ;;
    *)
        exit 0
        ;;
esac

tmux set-option -p -t "$TMUX_PANE" @agent_status "$state" >/dev/null 2>&1 || true
tmux refresh-client -S >/dev/null 2>&1 || true
