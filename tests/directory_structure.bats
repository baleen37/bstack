#!/usr/bin/env bats
# Test: Required directory structure

load helpers/bats_helper

@test "Required directories exist" {
    assert_dir_exists "${PROJECT_ROOT}/.claude-plugin" "root .claude-plugin directory should exist"
    assert_dir_exists "${PROJECT_ROOT}/hooks" "hooks directory should exist"
    assert_dir_exists "${PROJECT_ROOT}/scripts" "scripts directory should exist"
    assert_dir_exists "${PROJECT_ROOT}/skills" "skills directory should exist"
    assert_dir_exists "${PROJECT_ROOT}/dist" "dist directory should exist"
}

@test "Each plugin has valid plugin.json" {
    # Consolidated structure: single root-level plugin
    local plugin_json="${PROJECT_ROOT}/.claude-plugin/plugin.json"
    assert_file_exists "$plugin_json" "root plugin should have plugin.json"
    [ -s "$plugin_json" ]
}

@test "Plugin directories follow naming convention" {
    # Root plugin name should follow naming convention
    local name
    name=$(jq -r '.name' "${PROJECT_ROOT}/.claude-plugin/plugin.json" 2>/dev/null)
    is_valid_plugin_name "$name"
}
