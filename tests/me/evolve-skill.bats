#!/usr/bin/env bats
# /me:evolve 스킬 구조 검증

bats_require_minimum_version 1.5.0
load ../helpers/bats_helper

@test "evolve: skill files exist" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/apply-patch.sh" ]
}

@test "evolve: SKILL.md has proper frontmatter" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    has_frontmatter_delimiter "$f"
    has_frontmatter_field "$f" "name"
    has_frontmatter_field "$f" "description"
}

@test "evolve: scripts are executable" {
    [ -x "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
    [ -x "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/apply-patch.sh" ]
}

@test "evolve: apply-patch.sh blocks external cache writes" {
    local script="${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/apply-patch.sh"
    local patch="$BATS_TEST_TMPDIR/empty.patch"
    : > "$patch"
    run "$script" "$HOME/.claude/plugins/cache/foo/SKILL.md" "$patch" "x" "y" "z"
    [ "$status" -eq 10 ]
    [[ "$output" =~ "external plugin cache" ]] || [[ "$stderr" =~ "external plugin cache" ]]
}
