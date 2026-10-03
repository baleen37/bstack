#!/usr/bin/env bats
# Test: hooks.json validation

load helpers/bats_helper

HOOKS_JSON="${PROJECT_ROOT}/plugins/core/hooks/hooks.json"

setup() {
    ensure_jq
}

all_plugin_hooks_files() {
    find "${PROJECT_ROOT}/plugins" -path '*/hooks/hooks.json' -type f | sort
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
