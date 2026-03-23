#!/usr/bin/env bats
# Test: ralph-persist.ts Stop hook engine

load helpers/bats_helper

HOOK_SCRIPT="${PROJECT_ROOT}/plugins/ralph/hooks/ralph-persist.ts"
RALPH_DIR=""

setup() {
    RALPH_DIR="$(mktemp -d)/project"
    mkdir -p "${RALPH_DIR}/.ralph/state"
}

teardown() {
    rm -rf "$(dirname "$RALPH_DIR")"
}

# Helper: invoke the hook with given session_id and cwd
invoke_hook() {
    local session_id="${1:-test-session}"
    local cwd="${2:-$RALPH_DIR}"
    echo "{\"session_id\": \"$session_id\", \"cwd\": \"$cwd\", \"hook_event_name\": \"Stop\"}" \
        | bun run "$HOOK_SCRIPT"
}

# Helper: write state file
write_state() {
    local state="$1"
    echo "$state" > "${RALPH_DIR}/.ralph/state/ralph-state.json"
}

@test "no state file: writes nothing and exits 0" {
    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "active false: writes nothing and exits 0" {
    write_state '{"active":false,"session_id":"test-session","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z"}'
    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "session_id mismatch: writes nothing and exits 0" {
    write_state '{"active":true,"session_id":"session-A","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z"}'
    run invoke_hook "session-B"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "cancel signal exists: writes nothing, deletes signal, sets active false" {
    write_state '{"active":true,"session_id":"test-session","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z"}'
    touch "${RALPH_DIR}/.ralph/state/cancel-signal-state.json"

    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f "${RALPH_DIR}/.ralph/state/cancel-signal-state.json" ]
    local active
    active=$($JQ_BIN -r '.active' "${RALPH_DIR}/.ralph/state/ralph-state.json")
    [ "$active" = "false" ]
}

@test "stale state (>2h): writes nothing, sets active false" {
    local stale_time
    stale_time=$(date -u -v-3H '+%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null || date -u -d '3 hours ago' '+%Y-%m-%dT%H:%M:%S.000Z')
    write_state "{\"active\":true,\"session_id\":\"test-session\",\"iteration\":1,\"max_iterations\":100,\"last_checked_at\":\"$stale_time\"}"

    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    local active
    active=$($JQ_BIN -r '.active' "${RALPH_DIR}/.ralph/state/ralph-state.json")
    [ "$active" = "false" ]
}
