#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TMUX_PANE:-}" ]] || ! command -v tmux >/dev/null 2>&1; then
    exit 0
fi

payload="$(
    jq -r '
        if (.hook_event_name | type) == "string" and (.session_id | type) == "string" then
            [.hook_event_name, .session_id] | @tsv
        else
            empty
        end
    ' 2>/dev/null
)" || exit 0
[[ -n "$payload" ]] || exit 0

IFS=$'\t' read -r event session_id <<< "$payload"
[[ -n "$event" && -n "$session_id" ]] || exit 0

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
        current_session_id="$(
            tmux show-option -pv -t "$TMUX_PANE" @agent_status_session_id 2>/dev/null
        )" || exit 0
        [[ "$current_session_id" == "$session_id" ]] || exit 0

        tmux set-option -pu -t "$TMUX_PANE" @agent_status \; \
            set-option -pu -t "$TMUX_PANE" @agent_status_session_id \
            >/dev/null 2>&1 || true
        tmux refresh-client -S >/dev/null 2>&1 || true
        exit 0
        ;;
    *)
        exit 0
        ;;
esac

tmux set-option -p -t "$TMUX_PANE" @agent_status_session_id "$session_id" \; \
    set-option -p -t "$TMUX_PANE" @agent_status "$state" \
    >/dev/null 2>&1 || true
tmux refresh-client -S >/dev/null 2>&1 || true
