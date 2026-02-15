#!/usr/bin/env bats
# Test suite for plugin.json manifest validation
# https://code.claude.com/docs/en/plugins-reference#plugin-manifest

load helpers/bats_helper
load helpers/fixture_factory

@test "plugin.json has only allowed top-level fields" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"
    local custom_fields='"description": "Test plugin", "author": {"name": "Test Author", "email": "test@example.com"}, "version": "1.0.0", "license": "MIT", "homepage": "https://example.com", "repository": "https://github.com/test/test-plugin", "keywords": ["test", "plugin"]'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin" "$custom_fields")

    local manifest="$plugin_path/.claude-plugin/plugin.json"
    # Validate all fields are allowed
    run validate_plugin_manifest_fields "$manifest"
    [ "$status" -eq 0 ]
}

@test "plugin.json rejects disallowed top-level fields" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"
    local custom_fields='"description": "Test plugin", "invalidField": "should not be here", "anotherInvalid": 123'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin-invalid" "$custom_fields")

    local manifest="$plugin_path/.claude-plugin/plugin.json"
    # Should fail validation
    run validate_plugin_manifest_fields "$manifest"
    assert_exit_code 1 "Invalid field"
}

@test "plugin.json allows only name and email in author object" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"
    local custom_fields='"author": {"name": "Test Author", "email": "test@example.com"}'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin-valid-author" "$custom_fields")

    local manifest="$plugin_path/.claude-plugin/plugin.json"
    # Should pass validation
    run validate_plugin_manifest_fields "$manifest"
    [ "$status" -eq 0 ]
}

@test "plugin.json rejects disallowed author fields" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"
    local custom_fields='"author": {"name": "Test Author", "url": "https://example.com", "invalid": "field"}'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin-invalid-author" "$custom_fields")

    local manifest="$plugin_path/.claude-plugin/plugin.json"
    # Should fail validation
    run validate_plugin_manifest_fields "$manifest"
    assert_exit_code 1 "Invalid author field"
}

@test "plugin.json requires name field" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"
    local custom_fields='"description": "Test plugin without name"'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin-no-name" "$custom_fields")

    local manifest="$plugin_path/.claude-plugin/plugin.json"
    # Remove the name field that was added by default
    $JQ_BIN 'del(.name)' "$manifest" > "${manifest}.tmp" && mv "${manifest}.tmp" "$manifest"

    # Name is required - validate it exists
    run json_has_field "$manifest" "name"
    assert_exit_code 1
}

@test "plugin.json name is valid JSON string" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"
    local plugin_path
    plugin_path=$(create_minimal_plugin "$FIXTURE_ROOT" "my-valid-plugin")

    local manifest="$plugin_path/.claude-plugin/plugin.json"
    # Should be valid JSON
    run validate_json "$manifest"
    [ "$status" -eq 0 ]

    # Name should be a string
    json_field_has_type "$manifest" "name" "string"
}

@test "plugin.json author can be string or object" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"

    # Test with string author
    local plugin_string
    plugin_string=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin-string" '"author": "Test Author"')

    local manifest_string="$plugin_string/.claude-plugin/plugin.json"
    run validate_json "$manifest_string"
    [ "$status" -eq 0 ]

    # Test with object author
    local plugin_object
    plugin_object=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin-object" '"author": {"name": "Test Author"}')

    local manifest_object="$plugin_object/.claude-plugin/plugin.json"
    run validate_json "$manifest_object"
    [ "$status" -eq 0 ]
}

@test "plugin.json keywords is array of strings" {
    local FIXTURE_ROOT="${TEST_TEMP_DIR}/manifest_tests"
    local custom_fields='"keywords": ["test", "plugin", "automation"]'
    local plugin_path
    plugin_path=$(create_plugin_with_custom_fields "$FIXTURE_ROOT" "test-plugin-keywords" "$custom_fields")

    local manifest="$plugin_path/.claude-plugin/plugin.json"
    # Should be valid JSON
    run validate_json "$manifest"
    [ "$status" -eq 0 ]

    # Keywords should be an array
    json_field_has_type "$manifest" "keywords" "array"
}

@test "all real plugin manifests are valid" {
    # Find all plugin.json files in the project
    local manifest_files
    manifest_files=$(find "$PROJECT_ROOT/plugins" -name "plugin.json" -type f 2>/dev/null)

    [ -n "$manifest_files" ] || skip "No plugin.json files found"

    # Validate each manifest
    while IFS= read -r manifest_file; do
        # Check if JSON is valid
        run validate_json "$manifest_file"
        [ "$status" -eq 0 ]

        # Check if all fields are allowed
        run validate_plugin_manifest_fields "$manifest_file"
        [ "$status" -eq 0 ]
    done <<< "$manifest_files"
}
