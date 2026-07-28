#!/usr/bin/env bats

load ../helpers/bats_helper

HOOK="${PROJECT_ROOT}/plugins/me/hooks/agent-status.sh"
HOOKS_JSON="${PROJECT_ROOT}/plugins/me/hooks/hooks.json"

make_fake_tmux() {
    TMUX_LOG="${TEST_TEMP_DIR}/tmux.log"
    export TMUX_LOG

    cat > "${TEST_TEMP_DIR}/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMUX_LOG"
if [[ "$1" == "show-option" ]]; then
    [ -n "${TMUX_OWNER:-}" ] || exit 1
    printf '%s\n' "$TMUX_OWNER"
fi
EOF
    chmod +x "${TEST_TEMP_DIR}/tmux"
}

make_stateful_fake_tmux() {
    TMUX_LOG="${TEST_TEMP_DIR}/tmux.log"
    TMUX_STATE_DIR="${TEST_TEMP_DIR}/tmux-state"
    export TMUX_LOG TMUX_STATE_DIR
    mkdir "$TMUX_STATE_DIR"

    cat > "${TEST_TEMP_DIR}/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMUX_LOG"

while (($#)); do
    case "$1" in
        show-option)
            option="$5"
            if [[ "$option" == "@agent_status" ]]; then
                state_file="${TMUX_STATE_DIR}/status"
            else
                state_file="${TMUX_STATE_DIR}/session_id"
            fi
            [ -f "$state_file" ] || exit 1
            cat "$state_file"
            exit 0
            ;;
        set-option)
            flags="$2"
            option="$5"
            if [[ "$option" == "@agent_status" ]]; then
                state_file="${TMUX_STATE_DIR}/status"
            else
                state_file="${TMUX_STATE_DIR}/session_id"
            fi
            if [[ "$flags" == "-pu" ]]; then
                rm -f "$state_file"
                shift 5
            else
                printf '%s\n' "$6" > "$state_file"
                shift 6
            fi
            ;;
        refresh-client)
            exit 0
            ;;
        ';')
            shift
            ;;
        *)
            exit 1
            ;;
    esac
done
EOF
    chmod +x "${TEST_TEMP_DIR}/tmux"
}

assert_tmux_log() {
    local expected="$1"

    [ "$(cat "$TMUX_LOG")" = "$expected" ]
}

@test "agent status: SessionStart marks the pane ready and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"SessionStart","session_id":"session-1"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status_session_id session-1 ; set-option -p -t %7 @agent_status ready\nrefresh-client -S'
}

@test "agent status: UserPromptSubmit marks the pane running and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"UserPromptSubmit","session_id":"session-1"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status_session_id session-1 ; set-option -p -t %7 @agent_status running\nrefresh-client -S'
}

@test "agent status: PermissionRequest marks the pane needing input and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"PermissionRequest","session_id":"session-1"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status_session_id session-1 ; set-option -p -t %7 @agent_status needs_input\nrefresh-client -S'
}

@test "agent status: Stop marks the pane ready and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"Stop","session_id":"session-1"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status_session_id session-1 ; set-option -p -t %7 @agent_status ready\nrefresh-client -S'
}

@test "agent status: SessionEnd clears the pane status and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" TMUX_OWNER="session-1" \
        PATH="${TEST_TEMP_DIR}:$PATH" bash -c \
        'printf "%s\\n" '\''{"hook_event_name":"SessionEnd","session_id":"session-1"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'show-option -pv -t %7 @agent_status_session_id\nset-option -pu -t %7 @agent_status ; set-option -pu -t %7 @agent_status_session_id\nrefresh-client -S'
}

@test "agent status: missing TMUX_PANE is a successful no-op" {
    make_fake_tmux

    run env -u TMUX_PANE TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" "$HOOK"

    assert_success
    [ ! -e "$TMUX_LOG" ]
}

@test "agent status: missing tmux is a successful no-op" {
    mkdir "${TEST_TEMP_DIR}/no-tmux"

    run env PATH="${TEST_TEMP_DIR}/no-tmux" TMUX_PANE="%7" /bin/bash "$HOOK"

    assert_success
}

@test "agent status: malformed JSON is a successful no-op" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" "not-json" | "$1"' _ "$HOOK"

    assert_success
    [ ! -e "$TMUX_LOG" ]
}

@test "agent status: unknown events are a successful no-op" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"Other","session_id":"session-1"}'\'' | "$1"' _ "$HOOK"

    assert_success
    [ ! -e "$TMUX_LOG" ]
}

@test "agent status: tmux failures do not fail a known event" {
    ensure_jq
    cat > "${TEST_TEMP_DIR}/tmux" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "${TEST_TEMP_DIR}/tmux"

    run env TMUX_PANE="%7" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"SessionStart","session_id":"session-1"}'\'' | "$1"' _ "$HOOK"

    assert_success
}

@test "agent status: missing or empty session_id is a successful no-op" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"SessionStart"}'\'' | "$1"' _ "$HOOK"
    assert_success
    [ ! -e "$TMUX_LOG" ]

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"SessionEnd","session_id":""}'\'' | "$1"' _ "$HOOK"
    assert_success
    [ ! -e "$TMUX_LOG" ]
}

@test "agent status: all lifecycle registrations use the shared portable command" {
    ensure_jq

    local event
    local command='"${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/hooks/agent-status.sh"'
    for event in SessionStart UserPromptSubmit PermissionRequest Stop SessionEnd; do
        local timeout="5"
        if [[ "$event" == "SessionEnd" ]]; then
            timeout="3"
        fi
        [ "$($JQ_BIN -r ".hooks[\"$event\"][0].matcher" "$HOOKS_JSON")" = "*" ]
        [ "$($JQ_BIN -r ".hooks[\"$event\"][0].hooks[0].timeout" "$HOOKS_JSON")" = "$timeout" ]
        [ "$($JQ_BIN -r ".hooks[\"$event\"][0].hooks[0].command" "$HOOKS_JSON")" = "$command" ]
    done
}

@test "agent status: delayed SessionEnd cannot clear a newer pane owner" {
    ensure_jq
    make_stateful_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" TMUX_STATE_DIR="$TMUX_STATE_DIR" \
        PATH="${TEST_TEMP_DIR}:$PATH" bash -c \
        'printf "%s\\n" '\''{"hook_event_name":"SessionStart","session_id":"A"}'\'' | "$1"' _ "$HOOK"
    assert_success

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" TMUX_STATE_DIR="$TMUX_STATE_DIR" \
        PATH="${TEST_TEMP_DIR}:$PATH" bash -c \
        'printf "%s\\n" '\''{"hook_event_name":"UserPromptSubmit","session_id":"B"}'\'' | "$1"' _ "$HOOK"
    assert_success

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" TMUX_STATE_DIR="$TMUX_STATE_DIR" \
        PATH="${TEST_TEMP_DIR}:$PATH" bash -c \
        'printf "%s\\n" '\''{"hook_event_name":"SessionEnd","session_id":"A"}'\'' | "$1"' _ "$HOOK"
    assert_success
    [ "$(cat "${TMUX_STATE_DIR}/status")" = "running" ]
    [ "$(cat "${TMUX_STATE_DIR}/session_id")" = "B" ]

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" TMUX_STATE_DIR="$TMUX_STATE_DIR" \
        PATH="${TEST_TEMP_DIR}:$PATH" bash -c \
        'printf "%s\\n" '\''{"hook_event_name":"SessionEnd","session_id":"B"}'\'' | "$1"' _ "$HOOK"
    assert_success
    [ ! -e "${TMUX_STATE_DIR}/status" ]
    [ ! -e "${TMUX_STATE_DIR}/session_id" ]
}
