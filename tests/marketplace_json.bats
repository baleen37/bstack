#!/usr/bin/env bats
# Test: marketplace.json validation

load helpers/bats_helper
load helpers/marketplace_helper

MARKETPLACE_JSON="${PROJECT_ROOT}/.claude-plugin/marketplace.json"

setup() {
    ensure_jq
}

@test "marketplace.json exists" {
    assert_file_exists "$MARKETPLACE_JSON" "marketplace.json should exist"
}

@test "marketplace.json is valid JSON" {
    validate_json "$MARKETPLACE_JSON"
}

@test "marketplace.json has required fields" {
    json_has_field "$MARKETPLACE_JSON" "name"
    json_has_field "$MARKETPLACE_JSON" "owner.name"
    json_has_field "$MARKETPLACE_JSON" "plugins"
}

@test "marketplace.json owner.name is not empty" {
    local owner_name
    owner_name=$(json_get "$MARKETPLACE_JSON" "owner.name")
    assert_not_empty "$owner_name" "marketplace.json owner.name field should not be empty"
    # Also verify the field is a string
    assert_json_field_type "$MARKETPLACE_JSON" "owner.name" "string" "marketplace.json owner.name should be a string"
}

@test "marketplace.json plugins array exists" {
    assert_json_field_type "$MARKETPLACE_JSON" "plugins" "array" "marketplace.json plugins field should be an array"
}

@test "marketplace.json includes all plugins in plugins/ directory" {
    marketplace_all_plugins_listed "$MARKETPLACE_JSON"
}

@test "marketplace.json plugin sources point to existing directories" {
    marketplace_all_plugins_exist "$MARKETPLACE_JSON"
}
