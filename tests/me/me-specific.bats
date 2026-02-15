#!/usr/bin/env bats
# Consolidated plugin structure tests
# Tests for components that were previously in the me plugin

load ../helpers/bats_helper

@test "me: has all workflow commands" {
    [ -f "${PROJECT_ROOT}/commands/brainstorm.md" ]
    [ -f "${PROJECT_ROOT}/commands/debugging.md" ]
    [ -f "${PROJECT_ROOT}/commands/orchestrate.md" ]
    [ -f "${PROJECT_ROOT}/commands/refactor-clean.md" ]
    [ -f "${PROJECT_ROOT}/commands/research.md" ]
    [ -f "${PROJECT_ROOT}/commands/verify.md" ]
}

@test "me: code-reviewer agent exists with proper model" {
    local agent_file="${PROJECT_ROOT}/agents/code-reviewer.md"
    [ -f "$agent_file" ]
    has_frontmatter_field "$agent_file" "model"
}

# create-pr skill tests
@test "me: create-pr skill exists with required components" {
    [ -f "${PROJECT_ROOT}/skills/create-pr/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/skills/create-pr/scripts/check-conflicts.sh" ]
    [ -f "${PROJECT_ROOT}/skills/create-pr/scripts/verify-pr-status.sh" ]
    [ -f "${PROJECT_ROOT}/skills/create-pr/scripts/sync-with-base.sh" ]
}

@test "me: create-pr skill has proper frontmatter" {
    local skill_file="${PROJECT_ROOT}/skills/create-pr/SKILL.md"
    has_frontmatter_delimiter "$skill_file"
    has_frontmatter_field "$skill_file" "name"
    has_frontmatter_field "$skill_file" "description"
}

@test "me: create-pr scripts are executable" {
    [ -x "${PROJECT_ROOT}/skills/create-pr/scripts/check-conflicts.sh" ]
    [ -x "${PROJECT_ROOT}/skills/create-pr/scripts/verify-pr-status.sh" ]
    [ -x "${PROJECT_ROOT}/skills/create-pr/scripts/sync-with-base.sh" ]
}

@test "me: create-pr check-conflicts.sh validates git repo" {
    local script="${PROJECT_ROOT}/skills/create-pr/scripts/check-conflicts.sh"
    grep -q "git rev-parse.*git-dir" "$script"
}

@test "me: create-pr verify-pr-status.sh handles all PR states with CI checks" {
    local script="${PROJECT_ROOT}/skills/create-pr/scripts/verify-pr-status.sh"
    grep -q "CLEAN)" "$script"
    grep -q "BEHIND)" "$script"
    grep -q "DIRTY)" "$script"
    grep -q "statusCheckRollup" "$script"
    grep -q "isRequired" "$script"
    grep -q "BLOCKED|UNSTABLE" "$script"
}
