#!/usr/bin/env bats
# Test: ralph plugin hooks.json validation

load helpers/bats_helper

HOOKS_JSON="${PROJECT_ROOT}/plugins/ralph/hooks/hooks.json"

setup() {
    ensure_jq
}

@test "ralph hooks.json is valid JSON" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"
    validate_json "$HOOKS_JSON"
}

@test "ralph hooks.json has Stop hook" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"
    local has_stop
    has_stop=$($JQ_BIN -e '.hooks.Stop' "$HOOKS_JSON")
    [ -n "$has_stop" ]
}

@test "ralph hooks.json only has Codex-supported top-level fields" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"

    local unsupported_fields
    unsupported_fields=$($JQ_BIN -r 'keys - ["hooks"] | .[]' "$HOOKS_JSON")
    [ -z "$unsupported_fields" ]
}

@test "ralph hooks.json Stop hook uses plugin-root fallback" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"
    local command
    command=$($JQ_BIN -r '.hooks.Stop[0].hooks[0].command' "$HOOKS_JSON")
    [[ "$command" == *'${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}'* ]]
}
