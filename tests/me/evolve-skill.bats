#!/usr/bin/env bats
# /me:evolve 스킬 구조 검증

bats_require_minimum_version 1.5.0
load ../helpers/bats_helper

@test "evolve: skill files exist" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
}

@test "evolve: scripts are executable" {
    [ -x "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
}

@test "evolve: SKILL.md separates dry-run discovery from applying changes" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    grep -q "Dirty trees may still run read-only index and proposal discovery" "$f"
    grep -q "Before applying or committing selected patches" "$f"
}

@test "evolve: SKILL.md defines ordered no-signal handling" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    grep -q "Evaluate these conditions in order" "$f"
    grep -q "Some current skills have events" "$f"
}

@test "evolve: SKILL.md documents real multi-skill shorthand" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    grep -q "/me:evolve <skill> \\[<skill> ...\\]" "$f"
    grep -q "/me:evolve handoff pickup" "$f"
    grep -q -- "--skill handoff.*--skill pickup" "$f"
}

@test "evolve: SKILL.md documents path targets" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    grep -q "/me:evolve <worktree-or-transcript-path>" "$f"
    grep -q "/me:evolve --cwd <worktree-dir> --recent" "$f"
    grep -q "/me:evolve --cwd <worktree-dir> --skill <name>" "$f"
    grep -q "latest transcript for that" "$f"
    grep -q "recent or skill-focused analysis for another worktree" "$f"
    grep -q "do not forward the whole" "$f"
}

@test "evolve: SKILL.md blocks proposals when all skills are dropped" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    grep -q "All candidate skills dropped" "$f"
    grep -q "do not run proposal" "$f"
    grep -q "1 dropped: 1 missing_current_body" "$f"
}

@test "evolve: SKILL.md approval prompt includes commit scope" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    grep -q "Apply and commit? \\[all / none / P1 P3\\]" "$f"
    grep -q "show the plan only; do not ask for approval, apply patches, or commit" "$f"
}
