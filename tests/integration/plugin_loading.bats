#!/usr/bin/env bats
# Integration Test: Plugin Loading
# Tests that the consolidated plugin structure is valid

load ../helpers/bats_helper

@test "no hardcoded absolute paths in plugin manifest" {
    local plugin_json="${PROJECT_ROOT}/plugins/core/.claude-plugin/plugin.json"

    if [ -f "$plugin_json" ]; then
        # Check for absolute paths (not starting with ${ or /Users that's not ${CLAUDE_PLUGIN_ROOT})
        if grep -qE '"/(Users|home|opt)/' "$plugin_json" 2>/dev/null; then
            echo "Found hardcoded absolute path in: $plugin_json" >&2
            grep -E '"/(Users|home|opt)/' "$plugin_json" >&2
            return 1
        fi
    fi
}

@test "skill files follow naming convention" {
    local invalid_count=0

    for skill_file in "${PROJECT_ROOT}"/plugins/*/skills/*/SKILL.md; do
        if [ -f "$skill_file" ]; then
            # Check for SKILL.md in skill directory
            local skill_dir
            skill_dir=$(dirname "$skill_file")
            local skill_name
            skill_name=$(basename "$skill_dir")

            # Skill directory name should be valid
            if ! is_valid_plugin_name "$skill_name"; then
                echo "Invalid skill directory name: $skill_name" >&2
                invalid_count=$((invalid_count + 1))
            fi
        fi
    done

    assert_eq "$invalid_count" "0" "All skill directories should have valid names"
}
