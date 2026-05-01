#!/usr/bin/env bats
# Consolidated plugin structure tests
# Tests for components that were previously in the me plugin

bats_require_minimum_version 1.5.0

load ../helpers/bats_helper


@test "me: code-reviewer agent exists with proper model" {
    local agent_file="${PROJECT_ROOT}/plugins/core/agents/code-reviewer.md"
    [ -f "$agent_file" ]
    has_frontmatter_field "$agent_file" "model"
}

# create-pr skill tests
@test "me: create-pr skill exists with required components" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/create-pr/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/preflight-check.sh" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/wait-for-merge.sh" ]
}

@test "me: create-pr skill has proper frontmatter" {
    local skill_file="${PROJECT_ROOT}/plugins/me/skills/create-pr/SKILL.md"
    has_frontmatter_delimiter "$skill_file"
    has_frontmatter_field "$skill_file" "name"
    has_frontmatter_field "$skill_file" "description"
}

@test "me: create-pr scripts are executable" {
    [ -x "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/preflight-check.sh" ]
    [ -x "${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/wait-for-merge.sh" ]
}

@test "me: create-pr preflight-check.sh validates git repo" {
    local script="${PROJECT_ROOT}/plugins/me/skills/create-pr/scripts/preflight-check.sh"
    grep -q "git rev-parse.*git-dir" "$script"
}

@test "me: ship skill is self-contained" {
    local skill_file="${PROJECT_ROOT}/plugins/me/skills/ship/SKILL.md"

    [ -f "$skill_file" ]
    grep -q "Risk classification" "$skill_file"
    grep -q "Readiness dashboard" "$skill_file"
    # /ship delegates QA/E2E work to other skills rather than running them inline
    grep -q "Never run \`/qa\`, \`/e2e\`" "$skill_file"
}

@test "me: ship skill has proper frontmatter" {
    local skill_file="${PROJECT_ROOT}/plugins/me/skills/ship/SKILL.md"
    has_frontmatter_delimiter "$skill_file"
    has_frontmatter_field "$skill_file" "name"
    has_frontmatter_field "$skill_file" "description"
}

@test "me: ship skill has reference docs" {
    local ref_dir="${PROJECT_ROOT}/plugins/me/skills/ship/references"
    [ -f "${ref_dir}/review-checklist.md" ]
    [ -f "${ref_dir}/test-triage.md" ]
    [ -f "${ref_dir}/specialists/api-contract.md" ]
    [ -f "${ref_dir}/specialists/data-migration.md" ]
    [ -f "${ref_dir}/specialists/maintainability.md" ]
    [ -f "${ref_dir}/specialists/performance.md" ]
    [ -f "${ref_dir}/specialists/red-team.md" ]
    [ -f "${ref_dir}/specialists/security.md" ]
    [ -f "${ref_dir}/specialists/testing.md" ]
}

@test "me: land-and-deploy skill exists with proper frontmatter" {
    local skill_file="${PROJECT_ROOT}/plugins/me/skills/land-and-deploy/SKILL.md"
    [ -f "$skill_file" ]
    has_frontmatter_delimiter "$skill_file"
    has_frontmatter_field "$skill_file" "name"
    has_frontmatter_field "$skill_file" "description"
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
