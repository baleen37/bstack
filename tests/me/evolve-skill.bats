#!/usr/bin/env bats
# /me:evolve 스킬 구조 검증

bats_require_minimum_version 1.5.0
load ../helpers/bats_helper

@test "evolve: skill files exist" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
}

@test "evolve: SKILL.md has proper frontmatter" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    has_frontmatter_delimiter "$f"
    has_frontmatter_field "$f" "name"
    has_frontmatter_field "$f" "description"
}

@test "evolve: scripts are executable" {
    [ -x "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
}
