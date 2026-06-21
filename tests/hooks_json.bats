#!/usr/bin/env bats
# Test: hooks.json validation

load helpers/bats_helper

HOOKS_JSON="${PROJECT_ROOT}/plugins/me/hooks/hooks.json"

setup() {
    ensure_jq
}

all_plugin_hooks_files() {
    find "${PROJECT_ROOT}/plugins" -path '*/hooks/hooks.json' -type f | sort
}

@test "hooks.json is valid JSON" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"
    validate_json "$HOOKS_JSON"
}

@test "hooks.json has required top-level structure" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"

    # hooks field must exist and be an object
    json_has_field "$HOOKS_JSON" "hooks"

    local hooks_type
    hooks_type=$($JQ_BIN -r '.hooks | type' "$HOOKS_JSON")
    [ "$hooks_type" = "object" ]
}

@test "hooks.json only has Codex-supported top-level fields" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"

    local unsupported_fields
    unsupported_fields=$($JQ_BIN -r 'keys - ["hooks"] | .[]' "$HOOKS_JSON")
    [ -z "$unsupported_fields" ]
}

@test "all plugin hooks.json files only have Codex-supported top-level fields" {
    local hooks_file
    while IFS= read -r hooks_file; do
        local unsupported_fields
        unsupported_fields=$($JQ_BIN -r 'keys - ["hooks"] | .[]' "$hooks_file")
        if [ -n "$unsupported_fields" ]; then
            echo "Unsupported top-level fields in $hooks_file:"
            echo "$unsupported_fields"
            return 1
        fi
    done < <(all_plugin_hooks_files)
}

@test "hooks.json events have valid structure" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"

    local events
    events=$($JQ_BIN -r '.hooks | keys[]' "$HOOKS_JSON")

    while IFS= read -r event; do
        # Each event must be an array
        local event_type
        event_type=$($JQ_BIN -r ".hooks[\"$event\"] | type" "$HOOKS_JSON")
        [ "$event_type" = "array" ]

        # Each event entry must have matcher and hooks fields
        local entries
        entries=$($JQ_BIN -r ".hooks[\"$event\"] | length" "$HOOKS_JSON")
        for ((i=0; i<entries; i++)); do
            local has_matcher
            has_matcher=$($JQ_BIN -e ".hooks[\"$event\"][$i].matcher" "$HOOKS_JSON")
            [ -n "$has_matcher" ]

            local has_hooks
            has_hooks=$($JQ_BIN -e ".hooks[\"$event\"][$i].hooks" "$HOOKS_JSON")
            [ -n "$has_hooks" ]

            # hooks must be an array
            local hooks_arr_type
            hooks_arr_type=$($JQ_BIN -r ".hooks[\"$event\"][$i].hooks | type" "$HOOKS_JSON")
            [ "$hooks_arr_type" = "array" ]
        done
    done <<< "$events"
}

@test "hooks.json hook entries have required type field" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"

    local events
    events=$($JQ_BIN -r '.hooks | keys[]' "$HOOKS_JSON")

    while IFS= read -r event; do
        local entries
        entries=$($JQ_BIN -r ".hooks[\"$event\"] | length" "$HOOKS_JSON")
        for ((i=0; i<entries; i++)); do
            local hook_entries
            hook_entries=$($JQ_BIN -r ".hooks[\"$event\"][$i].hooks | length" "$HOOKS_JSON")
            for ((j=0; j<hook_entries; j++)); do
                local hook_type
                hook_type=$($JQ_BIN -r ".hooks[\"$event\"][$i].hooks[$j].type" "$HOOKS_JSON")
                [ "$hook_type" = "command" ] || [ "$hook_type" = "prompt" ] || [ "$hook_type" = "agent" ]
            done
        done
    done <<< "$events"
}

@test "hooks.json command type has command field" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"

    local events
    events=$($JQ_BIN -r '.hooks | keys[]' "$HOOKS_JSON")

    while IFS= read -r event; do
        local entries
        entries=$($JQ_BIN -r ".hooks[\"$event\"] | length" "$HOOKS_JSON")
        for ((i=0; i<entries; i++)); do
            local hook_entries
            hook_entries=$($JQ_BIN -r ".hooks[\"$event\"][$i].hooks | length" "$HOOKS_JSON")
            for ((j=0; j<hook_entries; j++)); do
                local hook_type
                hook_type=$($JQ_BIN -r ".hooks[\"$event\"][$i].hooks[$j].type" "$HOOKS_JSON")

                if [ "$hook_type" = "command" ]; then
                    local command
                    command=$($JQ_BIN -e ".hooks[\"$event\"][$i].hooks[$j].command" "$HOOKS_JSON")
                    [ -n "$command" ]
                fi
            done
        done
    done <<< "$events"
}

@test "hooks.json uses portable plugin-root paths" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"

    # Check for hardcoded absolute paths in command fields
    local has_hardcoded_path
    has_hardcoded_path=$($JQ_BIN -r '.. | .command? // empty' "$HOOKS_JSON" | grep -E '^/' || true)

    if [ -n "$has_hardcoded_path" ]; then
        echo "Error: Found hardcoded absolute path in $HOOKS_JSON"
        echo "Use \${PLUGIN_ROOT:-\$CLAUDE_PLUGIN_ROOT} instead"
        return 1
    fi

    local commands_missing_plugin_root
    commands_missing_plugin_root=$(
        $JQ_BIN -r '.. | .command? // empty' "$HOOKS_JSON" |
            grep -v '\${PLUGIN_ROOT:-\$CLAUDE_PLUGIN_ROOT}' || true
    )

    if [ -n "$commands_missing_plugin_root" ]; then
        echo "Error: Found command without Codex/Claude plugin-root fallback in $HOOKS_JSON"
        echo "$commands_missing_plugin_root"
        return 1
    fi
}

@test "all plugin hook commands use plugin-root fallback" {
    local hooks_file
    while IFS= read -r hooks_file; do
        local commands_missing_plugin_root
        commands_missing_plugin_root=$(
            $JQ_BIN -r '.. | .command? // empty' "$hooks_file" |
                grep -v '\${PLUGIN_ROOT:-\$CLAUDE_PLUGIN_ROOT}' || true
        )

        if [ -n "$commands_missing_plugin_root" ]; then
            echo "Error: Found command without Codex/Claude plugin-root fallback in $hooks_file"
            echo "$commands_missing_plugin_root"
            return 1
        fi
    done < <(all_plugin_hooks_files)
}
