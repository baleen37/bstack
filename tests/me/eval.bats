#!/usr/bin/env bats

load ../helpers/bats_helper

SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/eval/SKILL.md"

@test "eval: skill file exists" {
    [ -f "$SKILL_FILE" ]
}

@test "eval: skill has valid frontmatter delimiter" {
    has_frontmatter_delimiter "$SKILL_FILE"
}

@test "eval: skill has name field" {
    has_frontmatter_field "$SKILL_FILE" "name"
}

@test "eval: skill has description field" {
    has_frontmatter_field "$SKILL_FILE" "description"
}

@test "eval: skill name is eval" {
    grep -q "^name: eval$" "$SKILL_FILE"
}

@test "eval: skill description starts with Use when" {
    grep -q "^description: Use when" "$SKILL_FILE"
}

@test "eval: skill documents Phase 1 parallel subagents" {
    grep -qi "phase 1\|parallel" "$SKILL_FILE"
}

@test "eval: skill documents judge subagent" {
    grep -qi "judge" "$SKILL_FILE"
}

@test "eval: skill documents anonymization" {
    grep -qi "anon\|Option 1\|Option 2" "$SKILL_FILE"
}

@test "eval: skill documents PROMPT_A and PROMPT_B input format" {
    grep -q "PROMPT_A" "$SKILL_FILE"
    grep -q "PROMPT_B" "$SKILL_FILE"
}

@test "eval: skill documents winner output" {
    grep -qi "winner" "$SKILL_FILE"
}

@test "eval: skill documents tie as possible outcome" {
    grep -qi "tie\|Tie" "$SKILL_FILE"
}
