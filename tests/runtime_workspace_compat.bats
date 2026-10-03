#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "sdd-workspace moves a matching legacy ledger when the new path is absent" {
    local repo="$BATS_TEST_TMPDIR/repo"
    local plan="docs/plans/current.md"
    local old_workspace="$repo/.bstack/sdd/current"
    mkdir -p "$repo/docs/plans" "$old_workspace"
    git -C "$repo" init -q
    printf 'plan\n' > "$repo/$plan"
    printf '%s\n' "$plan" > "$old_workspace/plan-path"
    printf 'finished task 1\n' > "$old_workspace/progress.md"

    run bash -c 'cd "$1" && bash "$2" "$3"' _ "$repo" \
        "${PROJECT_ROOT}/plugins/core/skills/subagent-driven-development/scripts/sdd-workspace" "$plan"

    [ "$status" -eq 0 ]
    [ "$output" = "$(cd "$repo" && pwd -P)/.skills/sdd/current" ]
    [ -f "$repo/.skills/sdd/current/progress.md" ]
    [ "$(cat "$repo/.skills/sdd/current/progress.md")" = 'finished task 1' ]
    [ ! -e "$old_workspace" ]
}

@test "sdd-workspace stops when matching legacy and new ledgers both exist" {
    local repo="$BATS_TEST_TMPDIR/repo"
    local plan="docs/plans/current.md"
    local old_workspace="$repo/.bstack/sdd/current"
    local new_workspace="$repo/.skills/sdd/current"
    mkdir -p "$repo/docs/plans" "$old_workspace" "$new_workspace"
    git -C "$repo" init -q
    printf 'plan\n' > "$repo/$plan"
    printf '%s\n' "$plan" > "$old_workspace/plan-path"
    printf 'old progress\n' > "$old_workspace/progress.md"
    printf '%s\n' "$plan" > "$new_workspace/plan-path"
    printf 'new progress\n' > "$new_workspace/progress.md"

    run bash -c 'cd "$1" && bash "$2" "$3"' _ "$repo" \
        "${PROJECT_ROOT}/plugins/core/skills/subagent-driven-development/scripts/sdd-workspace" "$plan"

    [ "$status" -ne 0 ]
    [[ "$output" == *"both .bstack and .skills"* ]]
    [ "$(cat "$old_workspace/progress.md")" = 'old progress' ]
    [ "$(cat "$new_workspace/progress.md")" = 'new progress' ]
}

@test "sdd-workspace finds matching new ledger under a disambiguated name" {
    local repo="$BATS_TEST_TMPDIR/repo"
    local plan="docs/alpha/plan.md"
    local old_workspace="$repo/.bstack/sdd/plan"
    local new_workspace="$repo/.skills/sdd/plan-alpha"
    mkdir -p "$repo/docs/alpha" "$old_workspace" "$new_workspace"
    git -C "$repo" init -q
    printf 'plan\n' > "$repo/$plan"
    printf '%s\n' "$plan" > "$old_workspace/plan-path"
    printf 'old progress\n' > "$old_workspace/progress.md"
    printf '%s\n' "$plan" > "$new_workspace/plan-path"
    printf 'new progress\n' > "$new_workspace/progress.md"

    run bash -c 'cd "$1" && bash "$2" "$3"' _ "$repo" \
        "${PROJECT_ROOT}/plugins/core/skills/subagent-driven-development/scripts/sdd-workspace" "$plan"

    [ "$status" -ne 0 ]
    [[ "$output" == *"both .bstack and .skills"* ]]
    [ "$(cat "$old_workspace/progress.md")" = 'old progress' ]
    [ "$(cat "$new_workspace/progress.md")" = 'new progress' ]
}

@test "learn workspace moves a legacy topic when the new path is absent" {
    local home="$BATS_TEST_TMPDIR/home"
    local old_workspace="$home/.bstack/learn/git-basics"
    mkdir -p "$old_workspace"
    printf 'lesson 3\n' > "$old_workspace/NOTES.md"

    run env HOME="$home" bun "${PROJECT_ROOT}/plugins/core/skills/learn/scripts/resolve-workspace.ts" git-basics

    [ "$status" -eq 0 ]
    [ "$output" = "$home/.skills/learn/git-basics" ]
    [ "$(cat "$home/.skills/learn/git-basics/NOTES.md")" = 'lesson 3' ]
    [ ! -e "$old_workspace" ]
}

@test "learn workspace stops when legacy and new topic paths both exist" {
    local home="$BATS_TEST_TMPDIR/home"
    local old_workspace="$home/.bstack/learn/git-basics"
    local new_workspace="$home/.skills/learn/git-basics"
    mkdir -p "$old_workspace" "$new_workspace"
    printf 'old notes\n' > "$old_workspace/NOTES.md"
    printf 'new notes\n' > "$new_workspace/NOTES.md"

    run env HOME="$home" bun "${PROJECT_ROOT}/plugins/core/skills/learn/scripts/resolve-workspace.ts" git-basics

    [ "$status" -ne 0 ]
    [[ "$output" == *"both .bstack and .skills"* ]]
    [ "$(cat "$old_workspace/NOTES.md")" = 'old notes' ]
    [ "$(cat "$new_workspace/NOTES.md")" = 'new notes' ]
}

@test "old and new brainstorm paths remain ignored" {
    local repo="$BATS_TEST_DIRNAME/.."
    git -C "$repo" -c core.excludesFile=/dev/null check-ignore --no-index -q \
        .bstack/brainstorm/.last-token
    git -C "$repo" -c core.excludesFile=/dev/null check-ignore --no-index -q \
        .skills/brainstorm/.last-token
}
