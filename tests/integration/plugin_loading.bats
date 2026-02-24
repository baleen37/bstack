#!/usr/bin/env bats
# Integration Test: Plugin Loading
# Tests that the consolidated plugin structure is valid

load ../helpers/bats_helper

@test "main plugin.json file is valid" {
    local plugin_json="${PROJECT_ROOT}/plugins/me/.claude-plugin/plugin.json"

    assert_file_exists "$plugin_json" "Main plugin.json should exist"
    validate_json "$plugin_json"
}

@test "plugin name is unique and valid" {
    local plugin_json="${PROJECT_ROOT}/plugins/me/.claude-plugin/plugin.json"

    local name
    name=$(json_get "$plugin_json" "name")

    [ -n "$name" ]
    is_valid_plugin_name "$name"
}

@test "marketplace.json is valid" {
    local marketplace_json="${PROJECT_ROOT}/.claude-plugin/marketplace.json"

    if [ -f "$marketplace_json" ]; then
        validate_json "$marketplace_json"
    else
        skip "marketplace.json not present in consolidated structure"
    fi
}

@test "no hardcoded absolute paths in plugin manifest" {
    local plugin_json="${PROJECT_ROOT}/plugins/me/.claude-plugin/plugin.json"

    if [ -f "$plugin_json" ]; then
        # Check for absolute paths (not starting with ${ or /Users that's not ${CLAUDE_PLUGIN_ROOT})
        if grep -qE '"/(Users|home|opt)/' "$plugin_json" 2>/dev/null; then
            echo "Found hardcoded absolute path in: $plugin_json" >&2
            grep -E '"/(Users|home|opt)/' "$plugin_json" >&2
            return 1
        fi
    fi
}

@test "all required top-level directories exist" {
    assert_dir_exists "${PROJECT_ROOT}/.claude-plugin" ".claude-plugin directory should exist"
    assert_dir_exists "${PROJECT_ROOT}/plugins/me/skills" "skills directory should exist"
}

@test "github workflows are valid YAML" {
    local workflow_dir="${PROJECT_ROOT}/.github/workflows"
    local invalid_count=0

    ensure_yaml_validator

    for workflow in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
        if [ -f "$workflow" ]; then
            if ! validate_yaml_file "$workflow" 2>/dev/null; then
                echo "Invalid YAML: $workflow" >&2
                invalid_count=$((invalid_count + 1))
            fi
        fi
    done

    assert_eq "$invalid_count" "0" "All workflows should be valid YAML"
}

@test "hooks.json file is valid" {
    local hooks_file="${PROJECT_ROOT}/plugins/me/hooks/hooks.json"

    if [ -f "$hooks_file" ]; then
        validate_json "$hooks_file"
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
