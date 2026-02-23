#!/usr/bin/env bats
# Test: plugin.json validation
# This test file validates the root-level plugin.json manifest

load helpers/bats_helper
load helpers/test_utils

PLUGIN_JSON="${PROJECT_ROOT}/plugins/me/.claude-plugin/plugin.json"

setup() {
    ensure_jq
}

# Test: Verify plugin.json exists
@test "plugin.json exists" {
    [ -f "$PLUGIN_JSON" ]
}

# Test: plugin.json is valid JSON
@test "plugin.json is valid JSON" {
    validate_json "$PLUGIN_JSON"
}

# Test: plugin.json has required fields
@test "plugin.json has required fields" {
    local required_fields=("name" "description" "author")

    for field in "${required_fields[@]}"; do
        if ! json_has_field "$PLUGIN_JSON" "$field"; then
            echo "Missing '$field' in $PLUGIN_JSON" >&2
            return 1
        fi
    done
}

# Test: Plugin name follows naming convention (lowercase, hyphens, numbers)
@test "plugin.json name follows naming convention" {
    local name
    name=$(json_get "$PLUGIN_JSON" "name")
    is_valid_plugin_name "$name"
}

# Test: Required field values are not empty
@test "plugin.json fields are not empty" {
    local fields_to_check=("name" "description" "author")

    for field in "${fields_to_check[@]}"; do
        local value
        value=$(json_get "$PLUGIN_JSON" "$field")
        if [ -z "$value" ]; then
            echo "Field '$field' is empty in $PLUGIN_JSON" >&2
            return 1
        fi
    done
}

# Test: plugin.json uses only allowed fields
@test "plugin.json uses only allowed fields" {
    validate_plugin_manifest_fields "$PLUGIN_JSON"
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
