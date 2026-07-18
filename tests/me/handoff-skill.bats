#!/usr/bin/env bats

load ../helpers/bats_helper

setup() {
    SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/handoff/SKILL.md"
}

@test "me: handoff separates completed current and next state" {
    grep -q '^## Task$' "$SKILL_FILE"
    grep -q '^## Completed$' "$SKILL_FILE"
    grep -q '^## Current State$' "$SKILL_FILE"
    grep -q '^## Next Steps$' "$SKILL_FILE"
}

@test "me: handoff has one resume protocol without overlapping sections" {
    grep -q '^## Resume Protocol$' "$SKILL_FILE"
    run grep -q '^## Resume Prompt$' "$SKILL_FILE"
    assert_failure
    run grep -q '^## Resume Checkpoint$' "$SKILL_FILE"
    assert_failure
}

@test "me: handoff preserves XDG write-only boundaries" {
    grep -Fq '${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff' "$SKILL_FILE"
    grep -q 'write-only' "$SKILL_FILE"
    grep -q 'Does not start a new session or read prior handoffs' "$SKILL_FILE"
}

@test "me: handoff resolves XDG output once and reuses HANDOFF_DIR" {
    grep -Fq 'HANDOFF_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff"' "$SKILL_FILE"
    grep -Fq '$HANDOFF_DIR/YYYY-MM-DD-HHmm-<topic>.md' "$SKILL_FILE"
    grep -Fq 'Writes a file under `$HANDOFF_DIR`' "$SKILL_FILE"
    grep -Fq 'mkdir -p "$HANDOFF_DIR"' "$SKILL_FILE"
}

@test "me: handoff distinguishes temporary context from permanent rules" {
    grep -q 'AGENTS.md' "$SKILL_FILE"
    grep -q 'CLAUDE.md' "$SKILL_FILE"
    grep -q 'First action' "$SKILL_FILE"
    grep -q 'Last verified' "$SKILL_FILE"
}
