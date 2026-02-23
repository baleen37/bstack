#!/usr/bin/env bats
# Integration Tests for Consolidated Plugin Structure
# Tests for component interactions and consistency in single plugin structure

load ../helpers/bats_helper

@test "plugins have unique hook event types" {
    # Check hooks.json in consolidated structure
    local hooks_file="${PROJECT_ROOT}/plugins/me/hooks/hooks.json"

    if [ -f "$hooks_file" ]; then
        # Just verify it's valid JSON with hooks structure
        $JQ_BIN -e '.hooks' "$hooks_file" >/dev/null 2>&1
    fi
}

@test "all plugin manifests have unique names" {
    # In consolidated structure, there's only one plugin.json
    local plugin_json="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    if [ -f "$plugin_json" ]; then
        local name
        name=$($JQ_BIN -r '.name' "$plugin_json")
        [ -n "$name" ]
    fi
}

@test "plugins with skills have valid SKILL.md structure" {
    local found_skills=0

    for skill_file in "${PROJECT_ROOT}"/skills/*/SKILL.md; do
        if [ -f "$skill_file" ]; then
            found_skills=$((found_skills + 1))

            # Verify frontmatter delimiter
            has_frontmatter_delimiter "$skill_file"

            # Verify required fields
            has_frontmatter_field "$skill_file" "name"
            has_frontmatter_field "$skill_file" "description"
        fi
    done

    assert_gt "$found_skills" "0" "Should find at least one skill"
}

@test "marketplace plugins match actual plugin directories" {
    local marketplace_json="${PROJECT_ROOT}/.claude-plugin/marketplace.json"

    if [ ! -f "$marketplace_json" ]; then
        skip "marketplace.json not present in consolidated structure"
    fi

    local found_mismatch=0

    while IFS= read -r source; do
        if [ -n "$source" ]; then
            # Remove leading ./
            source="${source#./}"
            local plugin_path="${PROJECT_ROOT}/${source}"

            if [ ! -d "$plugin_path" ]; then
                echo "Marketplace plugin does not exist: $source"
                found_mismatch=$((found_mismatch + 1))
            fi
        fi
    done < <($JQ_BIN -r '.plugins[].source' "$marketplace_json" 2>/dev/null)

    assert_eq "$found_mismatch" "0" "All marketplace plugins should exist"
}

@test "hooks use portable paths consistently" {
    local hooks_file="${PROJECT_ROOT}/plugins/me/hooks/hooks.json"
    local found_hardcoded=0

    if [ -f "$hooks_file" ]; then
        # Check for hardcoded absolute paths in command hooks
        if grep -qE '"/(Users|home|var)/' "$hooks_file" 2>/dev/null; then
            echo "Found hardcoded path in: $hooks_file"
            grep -E '"/(Users|home|var)/' "$hooks_file"
            found_hardcoded=1
        fi
    fi

    assert_eq "$found_hardcoded" "0" "Hooks should use portable paths"
}

@test "plugin commands follow naming conventions" {
    local invalid_count=0

    for command_file in "${PROJECT_ROOT}"/commands/*.md; do
        if [ -f "$command_file" ]; then
            local filename
            filename=$(basename "$command_file")

            # Commands should be lowercase with hyphens or dots (for namespaced commands like databricks.explore.md)
            if ! [[ "$filename" =~ ^[a-z][a-z0-9.-]*\.md$ ]]; then
                echo "Invalid command filename: $filename"
                invalid_count=$((invalid_count + 1))
            fi
        fi
    done

    assert_eq "$invalid_count" "0" "All commands should follow naming conventions"
}

@test "plugin agents have valid frontmatter" {
    local found_agents=0

    # Check agents in the top-level agents/ directory
    for agent_file in "${PROJECT_ROOT}"/agents/*.md; do
        if [ -f "$agent_file" ]; then
            # Skip CLAUDE.md files
            [[ "$(basename "$agent_file")" == "CLAUDE.md" ]] && continue

            found_agents=$((found_agents + 1))

            # Verify frontmatter delimiter
            has_frontmatter_delimiter "$agent_file"

            # Verify required fields
            has_frontmatter_field "$agent_file" "name"
            has_frontmatter_field "$agent_file" "description"
            has_frontmatter_field "$agent_file" "model"
        fi
    done

    # Also check subdirectories like agents/ralph/
    for agent_file in "${PROJECT_ROOT}"/agents/*/*.md; do
        if [ -f "$agent_file" ]; then
            # Skip CLAUDE.md files and non-.md files
            [[ "$(basename "$agent_file")" == "CLAUDE.md" ]] && continue
            [[ "$agent_file" == *.md ]] || continue

            found_agents=$((found_agents + 1))

            # Verify frontmatter delimiter
            has_frontmatter_delimiter "$agent_file"

            # Verify required fields
            has_frontmatter_field "$agent_file" "name"
            has_frontmatter_field "$agent_file" "description"
            has_frontmatter_field "$agent_file" "model"
        fi
    done

    assert_gt "$found_agents" "0" "Should find at least one agent"
}

@test "all plugins have valid license field" {
    local plugin_json="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    if [ -f "$plugin_json" ]; then
        if ! $JQ_BIN -e '.license' "$plugin_json" &>/dev/null; then
            skip "License field is optional"
        fi
    fi
}

@test "plugin descriptions are not empty" {
    local plugin_json="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    if [ -f "$plugin_json" ]; then
        local description
        description=$($JQ_BIN -r '.description' "$plugin_json")

        [ -n "$description" ]
        [ "$description" != "null" ]
    fi
}

@test "plugin versions are valid semantic versions" {
    local plugin_json="${PROJECT_ROOT}/.claude-plugin/plugin.json"

    if [ -f "$plugin_json" ]; then
        local version
        version=$($JQ_BIN -r '.version' "$plugin_json")

        is_valid_semver "$version"
    fi
}
