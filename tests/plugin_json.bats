#!/usr/bin/env bats
# Test: plugin.json validation for all plugins under plugins/

load helpers/bats_helper
load helpers/test_utils

setup() {
    ensure_jq
}

# Test: all plugin.json files exist
@test "all plugins have plugin.json" {
    local plugin_dirs
    plugin_dirs=$(find_all_plugins)
    [ -n "$plugin_dirs" ]

    while IFS= read -r plugin_dir; do
        local manifest="${plugin_dir}/.claude-plugin/plugin.json"
        assert_file_exists "$manifest"
    done <<< "$plugin_dirs"
}

# Test: all plugin.json files are valid JSON
@test "all plugin.json files are valid JSON" {
    local plugin_dirs
    plugin_dirs=$(find_all_plugins)

    while IFS= read -r plugin_dir; do
        local manifest="${plugin_dir}/.claude-plugin/plugin.json"
        validate_json "$manifest"
    done <<< "$plugin_dirs"
}

# Test: all plugin.json files have required fields
@test "all plugin.json files have required fields" {
    local required_fields=("name" "description" "author")
    local plugin_dirs
    plugin_dirs=$(find_all_plugins)

    while IFS= read -r plugin_dir; do
        local manifest="${plugin_dir}/.claude-plugin/plugin.json"
        for field in "${required_fields[@]}"; do
            if ! json_has_field "$manifest" "$field"; then
                echo "Missing '$field' in $manifest" >&2
                return 1
            fi
        done
    done <<< "$plugin_dirs"
}

# Test: all plugin names follow naming convention (lowercase, hyphens, numbers)
@test "all plugin.json names follow naming convention" {
    local plugin_dirs
    plugin_dirs=$(find_all_plugins)

    while IFS= read -r plugin_dir; do
        local manifest="${plugin_dir}/.claude-plugin/plugin.json"
        local name
        name=$(json_get "$manifest" "name")
        if ! is_valid_plugin_name "$name"; then
            echo "Invalid plugin name '$name' in $manifest" >&2
            return 1
        fi
    done <<< "$plugin_dirs"
}

# Test: required field values are not empty in any plugin
@test "all plugin.json required fields are not empty" {
    local fields_to_check=("name" "description" "author")
    local plugin_dirs
    plugin_dirs=$(find_all_plugins)

    while IFS= read -r plugin_dir; do
        local manifest="${plugin_dir}/.claude-plugin/plugin.json"
        for field in "${fields_to_check[@]}"; do
            local value
            value=$(json_get "$manifest" "$field")
            if [ -z "$value" ]; then
                echo "Field '$field' is empty in $manifest" >&2
                return 1
            fi
        done
    done <<< "$plugin_dirs"
}

# Test: all plugin.json files use only allowed fields
@test "all plugin.json files use only allowed fields" {
    local plugin_dirs
    plugin_dirs=$(find_all_plugins)

    while IFS= read -r plugin_dir; do
        local manifest="${plugin_dir}/.claude-plugin/plugin.json"
        validate_plugin_manifest_fields "$manifest"
    done <<< "$plugin_dirs"
}

# Test: Comprehensive validation of all plugin manifests
@test "all plugin.json files pass comprehensive validation" {
    run check_all_plugin_manifests
    [ "$status" -eq 0 ]
    [[ "$output" == *"all"*"valid"* ]] || [[ "$output" == *"validation summary"* ]]
}

# Test: Count valid plugins returns positive number
@test "plugin count is valid" {
    local count
    count=$(count_valid_plugins)

    [ "$count" -gt 0 ]
}

# Test: No invalid plugins exist
@test "no invalid plugin manifests exist" {
    local invalid
    invalid=$(get_invalid_plugins)

    # If there are invalid plugins, output them for debugging
    if [ -n "$invalid" ]; then
        echo "Invalid plugins found:" >&2
        echo "$invalid" >&2
    fi

    # This test passes if there are no invalid plugins
    [ -z "$invalid" ]
}
