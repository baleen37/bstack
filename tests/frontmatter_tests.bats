#!/usr/bin/env bats
# Test: Component files have valid frontmatter
# Consolidated from command_files.bats, agent_files.bats, skill_files.bats

load helpers/bats_helper

# Command file tests
@test "Command files exist in plugins" {
    local command_count
    command_count=$(find "${PROJECT_ROOT}/plugins/me/commands" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$command_count" -gt 0 ]
}

@test "Command files have frontmatter delimiter" {
    while IFS= read -r -d '' file; do
        # Skip CLAUDE.md files (documentation, not commands)
        [[ "$(basename "$file")" == "CLAUDE.md" ]] && continue
        has_frontmatter_delimiter "$file"
    done < <(find "${PROJECT_ROOT}/plugins/me/commands" -name "*.md" -type f -print0 2>/dev/null)
}

# Agent file tests
@test "Agent files exist in plugins" {
    local agent_count
    agent_count=$(find "${PROJECT_ROOT}/plugins/me/agents" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$agent_count" -gt 0 ]
}

@test "Agent files have frontmatter delimiter" {
    while IFS= read -r -d '' file; do
        # Skip CLAUDE.md files (documentation, not agents)
        [[ "$(basename "$file")" == "CLAUDE.md" ]] && continue
        has_frontmatter_delimiter "$file"
    done < <(find "${PROJECT_ROOT}/plugins/me/agents" -name "*.md" -type f -print0 2>/dev/null)
}

# SKILL.md file tests
@test "SKILL.md files exist" {
    local skill_count
    skill_count=$(count_files "SKILL.md" "${PROJECT_ROOT}")
    [ "$skill_count" -gt 0 ]
}

@test "SKILL.md files have valid frontmatter delimiter" {
    while IFS= read -r -d '' file; do
        has_frontmatter_delimiter "$file"
    done < <(find "${PROJECT_ROOT}" -name "SKILL.md" -type f -print0 2>/dev/null)
}

@test "SKILL.md files have name field" {
    while IFS= read -r -d '' file; do
        has_frontmatter_field "$file" "name"
    done < <(find "${PROJECT_ROOT}" -name "SKILL.md" -type f -print0 2>/dev/null)
}

@test "SKILL.md files have description field" {
    while IFS= read -r -d '' file; do
        has_frontmatter_field "$file" "description"
    done < <(find "${PROJECT_ROOT}" -name "SKILL.md" -type f -print0 2>/dev/null)
}
