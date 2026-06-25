#!/usr/bin/env bats
# Consolidated plugin structure tests
# Tests for components that were previously in the me plugin

bats_require_minimum_version 1.5.0

load ../helpers/bats_helper


@test "me: code-reviewer agent exists with proper model" {
    local agent_file="${PROJECT_ROOT}/plugins/me/agents/code-reviewer.md"
    [ -f "$agent_file" ]
    has_frontmatter_field "$agent_file" "model"
}

# create-pr skill tests
@test "me: create-pr skill exists with required components" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/create-pr/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/create-pr.sh" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/preflight-check.sh" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/wait-for-merge.sh" ]
}

@test "me: create-pr scripts are executable" {
    [ -x "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/create-pr.sh" ]
    [ -x "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/preflight-check.sh" ]
    [ -x "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/wait-for-merge.sh" ]
}

@test "me: create-pr preflight-check.sh validates git repo" {
    local script="${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/preflight-check.sh"
    grep -q "git rev-parse.*git-dir" "$script"
}

@test "me: create-pr skill description is trigger-focused" {
    local skill="${PROJECT_ROOT}/plugins/me/skills/create-pr/SKILL.md"
    grep -q '^description: Use when ' "$skill"
}

@test "me: create-pr skill stays compact for frequent loading" {
    local skill="${PROJECT_ROOT}/plugins/me/skills/create-pr/SKILL.md"
    local words

    words=$(wc -w < "$skill")
    [ "$words" -le 260 ]
}

@test "me: lifecycle skills include test, review, and ship" {
    for skill in test review ship; do
        [ -f "${PROJECT_ROOT}/plugins/me/skills/${skill}/SKILL.md" ]
    done
}

@test "me: evolve skill exists" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
}

@test "me: release-with-github-app doc uses bun release flow" {
    local release_doc="${PROJECT_ROOT}/docs/release-with-github-app.yml"

    run grep -q "actions/setup-node" "$release_doc"
    assert_failure

    run grep -q "npm ci" "$release_doc"
    assert_failure

    run grep -q "npx semantic-release" "$release_doc"
    assert_failure

    run grep -q "node -p" "$release_doc"
    assert_failure

    grep -q "oven-sh/setup-bun" "$release_doc"
    grep -q "bun install" "$release_doc"
    grep -q "bunx semantic-release" "$release_doc"
}
