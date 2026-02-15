#!/usr/bin/env bats
# Test: plugin.json validation
# This test file validates plugin.json manifest files across all plugins

load helpers/bats_helper
load helpers/test_utils

setup() {
    ensure_jq
}

# Test: Verify at least one plugin.json exists
@test "plugin.json exists" {
    local found=0

    for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
            found=$((found + 1))
        fi
    done

    [ "$found" -gt 0 ]
}

# Test: All plugin.json files are valid JSON
@test "plugin.json is valid JSON" {
    local failed=0

    for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
            if ! validate_json "$manifest"; then
                ((failed++))
            fi
        fi
    done

    [ "$failed" -eq 0 ]
}

# Test: All plugin.json files have required fields
@test "plugin.json has required fields" {
    local failed=0
    local required_fields=("name" "description" "author")

    for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
            for field in "${required_fields[@]}"; do
                if ! json_has_field "$manifest" "$field"; then
                    echo "Missing '$field' in $manifest" >&2
                    ((failed++))
                fi
            done
        fi
    done

    [ "$failed" -eq 0 ]
}

# Test: All plugin names follow naming convention (lowercase, hyphens, numbers)
@test "plugin.json name follows naming convention" {
    local failed=0

    for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
            local name
            name=$(json_get "$manifest" "name")
            if ! is_valid_plugin_name "$name"; then
                echo "Invalid plugin name '$name' in $manifest" >&2
                ((failed++))
            fi
        fi
    done

    [ "$failed" -eq 0 ]
}

# Test: All required field values are not empty
@test "plugin.json fields are not empty" {
    local failed=0
    local fields_to_check=("name" "description" "author")

    for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
            for field in "${fields_to_check[@]}"; do
                local value
                value=$(json_get "$manifest" "$field")
                if [ -z "$value" ]; then
                    echo "Field '$field' is empty in $manifest" >&2
                    ((failed++))
                fi
            done
        fi
    done

    [ "$failed" -eq 0 ]
}

# Test: All plugin.json files use only allowed fields
@test "plugin.json uses only allowed fields" {
    local failed=0

    for manifest in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
        if [ -f "$manifest" ]; then
            if ! validate_plugin_manifest_fields "$manifest"; then
                ((failed++))
            fi
        fi
    done

    [ "$failed" -eq 0 ]
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
