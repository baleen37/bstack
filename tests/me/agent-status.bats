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
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"SessionStart"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status ready\nrefresh-client -S'
}

@test "agent status: UserPromptSubmit marks the pane running and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"UserPromptSubmit"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status running\nrefresh-client -S'
}

@test "agent status: PermissionRequest marks the pane needing input and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"PermissionRequest"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status needs_input\nrefresh-client -S'
}

@test "agent status: Stop marks the pane ready and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"Stop"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -p -t %7 @agent_status ready\nrefresh-client -S'
}

@test "agent status: SessionEnd clears the pane status and refreshes" {
    ensure_jq
    make_fake_tmux

    run env TMUX_PANE="%7" TMUX_LOG="$TMUX_LOG" PATH="${TEST_TEMP_DIR}:$PATH" \
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"SessionEnd"}'\'' | "$1"' _ "$HOOK"

    assert_success
    assert_tmux_log $'set-option -pu -t %7 @agent_status\nrefresh-client -S'
}

@test "agent status: missing TMUX_PANE is a successful no-op" {
    run env -u TMUX_PANE "$HOOK"

    assert_success
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
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"Other"}'\'' | "$1"' _ "$HOOK"

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
        bash -c 'printf "%s\\n" '\''{"hook_event_name":"SessionStart"}'\'' | "$1"' _ "$HOOK"

    assert_success
}

@test "agent status: all lifecycle registrations use the shared portable command" {
    ensure_jq

    local event
    local command='"${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/hooks/agent-status.sh"'
    for event in SessionStart UserPromptSubmit PermissionRequest Stop SessionEnd; do
        [ "$($JQ_BIN -r ".hooks[\"$event\"][0].matcher" "$HOOKS_JSON")" = "*" ]
        [ "$($JQ_BIN -r ".hooks[\"$event\"][0].hooks[0].timeout" "$HOOKS_JSON")" = "5" ]
        [ "$($JQ_BIN -r ".hooks[\"$event\"][0].hooks[0].command" "$HOOKS_JSON")" = "$command" ]
    done
}
