#!/usr/bin/env bash
# Fixture Factory for BATS tests
#
# This library provides helper functions to create test fixtures for Claude Code plugins.
# It follows TDD principles and is designed to work seamlessly with the existing
# bats_helper.bash functions.
#
# Usage:
#   load helpers/fixture_factory
#
#   # Create a minimal plugin for testing
#   plugin_path=$(create_minimal_plugin "$TEST_TEMP_DIR" "my-plugin")
#
#   # Create a full plugin with all components
#   full_plugin=$(create_full_plugin "$TEST_TEMP_DIR" "full-plugin")
#
#   # Create individual component files
#   create_command_file "$plugin_path/commands" "my-command" "Description"
#   create_agent_file "$plugin_path/agents" "my-agent" "Description" "sonnet"
#   create_skill_file "$plugin_path/skills" "my-skill" "Description"
#
#   # Create marketplace.json
#   create_marketplace_json "$TEST_TEMP_DIR/marketplace.json" "test-marketplace" "Test" "Owner"
#
#   # Create hooks.json
#   create_hooks_json "$TEST_TEMP_DIR/hooks/hooks.json" "Test hooks"
#
#   # Create SKILL.md directly
#   create_skill_md "$TEST_TEMP_DIR/SKILL.md" "skill-name" "Description" "Content"
#
#   # Create plugin with custom fields
#   create_plugin_with_custom_fields "$TEST_TEMP_DIR" "custom-plugin" '"version": "2.0.0", "custom": "field"'
#
#   # Create handoff JSON for testing
#   create_handoff_json "$TEST_TEMP_DIR/handoff.json" "test-id" "2026-02-08T10:00:00Z" "/project/path" "Summary" "main" "project-name"
#
#   # Create GitHub Actions workflow YAML for testing
#   create_workflow_yaml "$TEST_TEMP_DIR/workflow.yml" "Test Workflow" "on: push"
#
#   # Clean up fixtures
#   cleanup_fixtures "$FIXTURE_ROOT"
#
# Functions:
#   - create_minimal_plugin(): Create minimal plugin structure with plugin.json only
#   - create_full_plugin(): Create complete plugin with all directories and sample files
#   - create_command_file(): Create a command file with frontmatter
#   - create_agent_file(): Create an agent file with frontmatter
#   - create_skill_file(): Create a skill directory and SKILL.md file
#   - create_marketplace_json(): Create a marketplace.json file with plugins list
#   - create_hooks_json(): Create a hooks.json file with hook configurations
#   - create_skill_md(): Create a SKILL.md file with frontmatter
#   - create_plugin_with_custom_fields(): Create a plugin.json with custom JSON fields
#   - create_handoff_json(): Create a handoff JSON file with test data
#   - create_workflow_yaml(): Create a GitHub Actions workflow YAML file
#   - cleanup_fixtures(): Safely remove fixture directories

# Ensure JQ_BIN is set
JQ_BIN="${JQ_BIN:-jq}"

# Default values
DEFAULT_VERSION="1.0.0"
DEFAULT_AUTHOR_NAME="Test Author"
DEFAULT_AUTHOR_EMAIL="test@example.com"
DEFAULT_LICENSE="MIT"
DEFAULT_DESCRIPTION="Test plugin description"

# Validate plugin name format (lowercase, hyphens, numbers only)
_validate_plugin_name() {
    local name="$1"
    if [[ ! "$name" =~ ^[a-z0-9-]+$ ]]; then
        echo "Error: Invalid plugin name '$name'. Plugin names must be lowercase with hyphens only." >&2
        return 1
    fi
    return 0
}

# Create minimal plugin structure
# Args: base_dir, plugin_name, [version], [author_name], [author_email]
# Returns: Path to created plugin
create_minimal_plugin() {
    local base_dir="$1"
    local plugin_name="$2"
    local version="${3:-$DEFAULT_VERSION}"
    local author_name="${4:-$DEFAULT_AUTHOR_NAME}"
    local author_email="${5:-$DEFAULT_AUTHOR_EMAIL}"

    # Validate plugin name
    _validate_plugin_name "$plugin_name" || return 1

    local plugin_path="$base_dir/$plugin_name"
    local manifest_dir="$plugin_path/.claude-plugin"
    local manifest_file="$manifest_dir/plugin.json"

    # Create directory structure
    mkdir -p "$manifest_dir"

    # Create plugin.json with author as object
    cat > "$manifest_file" <<EOF
{
  "name": "$plugin_name",
  "version": "$version",
  "description": "$DEFAULT_DESCRIPTION",
  "author": {
    "name": "$author_name",
    "email": "$author_email"
  }
}
EOF

    echo "$plugin_path"
}

# Create full plugin structure with all components
# Args: base_dir, plugin_name, [version], [author_name], [author_email]
# Returns: Path to created plugin
create_full_plugin() {
    local base_dir="$1"
    local plugin_name="$2"
    local version="${3:-$DEFAULT_VERSION}"
    local author_name="${4:-$DEFAULT_AUTHOR_NAME}"
    local author_email="${5:-$DEFAULT_AUTHOR_EMAIL}"

    # Validate plugin name
    _validate_plugin_name "$plugin_name" || return 1

    local plugin_path="$base_dir/$plugin_name"

    # Create minimal plugin first
    create_minimal_plugin "$base_dir" "$plugin_name" "$version" "$author_name" "$author_email" > /dev/null

    # Add additional fields to plugin.json
    local manifest_file="$plugin_path/.claude-plugin/plugin.json"
    # shellcheck disable=SC2016
    $JQ_BIN -r --arg license "$DEFAULT_LICENSE" \
        '. + {license: $license, keywords: ["test", "fixture"]}' \
        "$manifest_file" > "${manifest_file}.tmp" && \
        mv "${manifest_file}.tmp" "$manifest_file"

    # Create directory structure
    mkdir -p "$plugin_path/commands"
    mkdir -p "$plugin_path/agents"
    mkdir -p "$plugin_path/skills"
    mkdir -p "$plugin_path/hooks"

    # Create sample command
    create_command_file "$plugin_path/commands" "example-command" "Example command description"

    # Create sample agent
    create_agent_file "$plugin_path/agents" "example-agent" "Example agent description" "sonnet"

    # Create sample skill
    create_skill_file "$plugin_path/skills" "example-skill" "Example skill description"

    # Create hooks.json
    cat > "$plugin_path/hooks/hooks.json" <<EOF
{
  "description": "Example hooks configuration",
  "hooks": {
    "SessionStart": []
  }
}
EOF

    echo "$plugin_path"
}

# Create a command file with frontmatter
# Args: commands_dir, command_name, description
create_command_file() {
    local commands_dir="$1"
    local command_name="$2"
    local description="$3"

    local command_file="$commands_dir/${command_name}.md"

    cat > "$command_file" <<EOF
---
description: $description
---

Content for ${command_name}
EOF
}

# Create an agent file with frontmatter
# Args: agents_dir, agent_name, description, model
create_agent_file() {
    local agents_dir="$1"
    local agent_name="$2"
    local description="$3"
    local model="${4:-sonnet}"

    local agent_file="$agents_dir/${agent_name}.md"

    cat > "$agent_file" <<EOF
---
name: $agent_name
description: |
  $description
model: $model
---

You are a specialized agent for ${agent_name}.
EOF
}

# Create a skill directory and SKILL.md file
# Args: skills_dir, skill_name, description, [content]
create_skill_file() {
    local skills_dir="$1"
    local skill_name="$2"
    local description="$3"
    local content="${4:-}"

    local skill_dir="$skills_dir/${skill_name}"
    local skill_file="$skill_dir/SKILL.md"

    mkdir -p "$skill_dir"

    # If custom content provided, use it; otherwise generate default
    if [ -n "$content" ]; then
        cat > "$skill_file" <<EOF
---
name: $skill_name
description: $description
---

$content
EOF
    else
        # Capitalize first letter for title using bash
        local skill_name_cap
        skill_name_cap="${skill_name^}"

        cat > "$skill_file" <<EOF
---
name: $skill_name
description: $description
---

# ${skill_name_cap}

## Overview

This is a test skill for ${skill_name}.

## Usage

Use this skill when you need to test ${skill_name} functionality.
EOF
    fi
}

# Create a marketplace.json file with plugins list
# Args: output_path, marketplace_name, marketplace_description, owner_name, [owner_email], [plugins_json]
# Returns: Path to created marketplace.json
create_marketplace_json() {
    local output_path="$1"
    local marketplace_name="$2"
    local marketplace_description="${3:-Test marketplace}"
    local owner_name="${4:-Test Owner}"
    local owner_email="${5:-}"
    local plugins_json="${6:-[]}"

    local marketplace_dir
    marketplace_dir=$(dirname "$output_path")
    mkdir -p "$marketplace_dir"

    # Build owner object
    local owner_json
    if [ -n "$owner_email" ]; then
        owner_json=$(cat <<EOF
{
  "name": "$owner_name",
  "email": "$owner_email"
}
EOF
)
    else
        owner_json=$(cat <<EOF
{
  "name": "$owner_name"
}
EOF
)
    fi

    # Create marketplace.json
    cat > "$output_path" <<EOF
{
  "name": "$marketplace_name",
  "description": "$marketplace_description",
  "owner": $owner_json,
  "plugins": $plugins_json
}
EOF

    echo "$output_path"
}

# Create a hooks.json file with hook configurations
# Args: output_path, [description], [hooks_json]
# Returns: Path to created hooks.json
create_hooks_json() {
    local output_path="$1"
    local description="${2:-Test hooks configuration}"
    local hooks_json="${3:-{\}}"

    local hooks_dir
    hooks_dir=$(dirname "$output_path")
    mkdir -p "$hooks_dir"

    # Create hooks.json
    cat > "$output_path" <<EOF
{
  "description": "$description",
  "hooks": $hooks_json
}
EOF

    echo "$output_path"
}

# Create a SKILL.md file with frontmatter
# Args: output_path, skill_name, description, [content], [additional_frontmatter]
# Returns: Path to created SKILL.md
create_skill_md() {
    local output_path="$1"
    local skill_name="$2"
    local description="$3"
    local content="${4:-}"
    local additional_frontmatter="${5:-}"

    local skill_dir
    skill_dir=$(dirname "$output_path")
    mkdir -p "$skill_dir"

    # Build frontmatter
    local frontmatter="name: $skill_name\ndescription: $description"
    if [ -n "$additional_frontmatter" ]; then
        frontmatter="$frontmatter\n$additional_frontmatter"
    fi

    # Create SKILL.md
    cat > "$output_path" <<EOF
---
$frontmatter
---

$content
EOF

    echo "$output_path"
}

# Create a plugin.json with custom JSON fields
# Args: base_dir, plugin_name, custom_json_fields
# Returns: Path to created plugin
create_plugin_with_custom_fields() {
    local base_dir="$1"
    local plugin_name="$2"
    local custom_json_fields="$3"

    # Validate plugin name
    _validate_plugin_name "$plugin_name" || return 1

    local plugin_path="$base_dir/$plugin_name"
    local manifest_dir="$plugin_path/.claude-plugin"
    local manifest_file="$manifest_dir/plugin.json"

    # Create directory structure
    mkdir -p "$manifest_dir"

    # Create plugin.json with custom fields
    cat > "$manifest_file" <<EOF
{
  "name": "$plugin_name",
$custom_json_fields
}
EOF

    echo "$plugin_path"
}

# Create a handoff JSON file with test data
# Args: output_path, handoff_id, created_at, project_path, [summary], [branch], [project_name], [plan_path], [tasks_session_id], [loaded_at], [source_session_id]
# Returns: Path to created handoff JSON
create_handoff_json() {
    local output_path="$1"
    local handoff_id="$2"
    local created_at="${3:-}"
    local project_path="$4"
    local summary="${5:-Test handoff summary}"
    local branch="${6:-main}"
    local project_name="${7:-test-project}"
    local plan_path="${8:-null}"
    local tasks_session_id="${9:-null}"
    local loaded_at="${10:-null}"
    local source_session_id="${11:-null}"

    local handoff_dir
    handoff_dir=$(dirname "$output_path")
    mkdir -p "$handoff_dir"

    # Use current time if created_at not provided
    if [ -z "$created_at" ]; then
        created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    fi

    # Determine plan_path JSON value (null or string)
    local plan_path_json
    if [ "$plan_path" = "null" ]; then
        plan_path_json="null"
    else
        plan_path_json="\"$plan_path\""
    fi

    # Determine tasks_session_id JSON value (null or string)
    local tasks_session_id_json
    if [ "$tasks_session_id" = "null" ]; then
        tasks_session_id_json="null"
    else
        tasks_session_id_json="\"$tasks_session_id\""
    fi

    # Determine loaded_at JSON value (null or string)
    local loaded_at_json
    if [ "$loaded_at" = "null" ]; then
        loaded_at_json="null"
    else
        loaded_at_json="\"$loaded_at\""
    fi

    # Determine source_session_id JSON value (null or string)
    local source_session_id_json
    if [ "$source_session_id" = "null" ]; then
        source_session_id_json="null"
    else
        source_session_id_json="\"$source_session_id\""
    fi

    # Create handoff JSON
    cat > "$output_path" <<EOF
{
  "id": "$handoff_id",
  "created_at": "$created_at",
  "loaded_at": $loaded_at_json,
  "project_name": "$project_name",
  "project_path": "$project_path",
  "branch": "$branch",
  "summary": "$summary",
  "references": {
    "plan_path": $plan_path_json,
    "tasks_session_id": $tasks_session_id_json
  },
  "source_session_id": $source_session_id_json
}
EOF

    echo "$output_path"
}

# Create a GitHub Actions workflow YAML file
# Args: output_path, workflow_name, [trigger_yaml], [permissions_yaml], [jobs_yaml]
# Returns: Path to created workflow YAML
create_workflow_yaml() {
    local output_path="$1"
    local workflow_name="$2"
    local trigger_yaml="${3:-on: push}"
    local permissions_yaml="${4:-permissions: {}}"
    local jobs_yaml="${5:-}"

    local workflow_dir
    workflow_dir=$(dirname "$output_path")
    mkdir -p "$workflow_dir"

    # Create workflow YAML
    cat > "$output_path" <<EOF
name: ${workflow_name}

${trigger_yaml}

${permissions_yaml}
EOF

    # Add jobs section if provided
    if [ -n "$jobs_yaml" ]; then
        cat >> "$output_path" <<EOF

jobs:
${jobs_yaml}
EOF
    fi

    echo "$output_path"
}

# Clean up fixture directories
# Args: fixture_root
cleanup_fixtures() {
    local fixture_root="$1"

    # Only remove if it exists and is under TEST_TEMP_DIR
    if [ -n "${TEST_TEMP_DIR:-}" ]; then
        if [[ "$fixture_root" == "$TEST_TEMP_DIR"* ]]; then
            if [ -d "$fixture_root" ]; then
                rm -rf "$fixture_root" || true
            fi
        fi
    fi

    return 0
}
