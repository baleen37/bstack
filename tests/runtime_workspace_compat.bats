#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
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
