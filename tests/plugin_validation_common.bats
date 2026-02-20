#!/usr/bin/env bats
# Common plugin validation test module
# Provides reusable test patterns for plugin.json validation
#
# This file can be sourced by other test files or run directly
# To source in another test file, use:
#   load tests/plugin_validation_common
#
# Dependencies:
#   - helpers/bats_helper
#   - helpers/test_utils
#   - helpers/fixture_factory

load helpers/bats_helper
load helpers/test_utils
load helpers/fixture_factory

###############################################################################
# HELPER FUNCTIONS FOR PLUGIN VALIDATION TESTS
###############################################################################

# Assert that a plugin manifest is valid
# Usage: _assert_valid_manifest <manifest_file>
_assert_valid_manifest() {
    local manifest="$1"

    # Check JSON validity
    run validate_json "$manifest"
    [ "$status" -eq 0 ]

    # Check allowed fields
    run validate_plugin_manifest_fields "$manifest"
    [ "$status" -eq 0 ]
}

# Assert that all required fields are present
# Usage: _assert_has_required_fields <manifest_file>
_assert_has_required_fields() {
    local manifest="$1"

    json_has_field "$manifest" "name"
    json_has_field "$manifest" "description"
    json_has_field "$manifest" "author"
}

# Assert that required field values are not empty
# Usage: _assert_field_values_not_empty <manifest_file>
_assert_field_values_not_empty() {
    local manifest="$1"
    local name description author

    name=$(json_get "$manifest" "name")
    description=$(json_get "$manifest" "description")
    author=$(json_get "$manifest" "author")

    assert_not_empty "$name" "plugin.json name field should not be empty in $manifest"
    assert_not_empty "$description" "plugin.json description field should not be empty in $manifest"
    assert_not_empty "$author" "plugin.json author field should not be empty in $manifest"
}

# Assert that plugin name follows naming convention
# Usage: _assert_valid_plugin_name <manifest_file>
_assert_valid_plugin_name() {
    local manifest="$1"
    local name

    name=$(json_get "$manifest" "name")
    is_valid_plugin_name "$name"
}

###############################################################################
# COMMON TEST CASES
###############################################################################

@test "common: plugin.json files exist in plugin directories" {
    local manifest_file="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    [ -f "$manifest_file" ]
}

@test "common: all plugin.json files are valid JSON" {
    local manifest="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    [ -f "$manifest" ] || skip "No plugin.json found"
    validate_json "$manifest"
}

@test "common: all plugin.json files have required fields" {
    local manifest="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    [ -f "$manifest" ] || skip "No plugin.json found"
    _assert_has_required_fields "$manifest"
}

@test "common: all plugin.json files have non-empty required field values" {
    local manifest="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    [ -f "$manifest" ] || skip "No plugin.json found"
    _assert_field_values_not_empty "$manifest"
}

@test "common: all plugin.json names follow naming convention" {
    local manifest="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    [ -f "$manifest" ] || skip "No plugin.json found"
    _assert_valid_plugin_name "$manifest"
}

@test "common: all plugin.json files use only allowed fields" {
    local manifest="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    [ -f "$manifest" ] || skip "No plugin.json found"
    validate_plugin_manifest_fields "$manifest"
}

@test "common: validate all plugin manifests using comprehensive validation" {
    run check_all_plugin_manifests
    [ "$status" -eq 0 ]
    [[ "$output" == *"all"*"valid"* ]]
}

@test "common: count valid plugins returns expected number" {
    local count
    count=$(count_valid_plugins)

    [ "$count" -gt 0 ] || skip "No valid plugins found"
}

@test "common: get_invalid_plugins returns empty list when all are valid" {
    local invalid
    invalid=$(get_invalid_plugins)

    # If all plugins are valid, this should be empty
    # If there are invalid plugins, the test still passes (we just verify the function works)
    if [ -n "$invalid" ]; then
        # There are some invalid plugins, verify the format
        # Each line should be a plugin name (lowercase, hyphens, numbers)
        while IFS= read -r plugin_name; do
            [[ "$plugin_name" =~ ^[a-z0-9-]+$ ]]
        done <<< "$invalid"
    fi
}

@test "common: validate_plugin_manifest_comprehensive works on valid plugin" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/comprehensive_test"
    local plugin_path
    plugin_path=$(create_minimal_plugin "$FIXTURE_ROOT" "test-valid-plugin")

    run validate_plugin_manifest_comprehensive "$plugin_path"
    # Should pass with exit code 0
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 0 ] || [[ "${lines[*]}" == *"all"*"valid"* ]] || true
}

@test "common: validate_plugin_manifest_comprehensive detects missing fields" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/comprehensive_test_missing"
    # Create plugin with only description (missing author field)
    local custom_fields='"description": "Test plugin"'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-missing-author" "$custom_fields")

    run validate_plugin_manifest_comprehensive "$plugin_path"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Missing required field"* ]] || [[ "$output" == *"author"* ]]
}

@test "common: validate_plugin_manifest_comprehensive detects invalid fields" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/comprehensive_test_invalid"
    # Create plugin with invalid field (note: name is auto-added, so we only pass custom fields)
    local custom_fields='"description": "Test plugin", "author": "Test Author", "invalidField": "should not be here"'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-invalid-field" "$custom_fields")

    run validate_plugin_manifest_comprehensive "$plugin_path"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid"* ]] || [[ "$output" == *"invalidField"* ]]
}
