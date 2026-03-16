#!/usr/bin/env bats

load ../helpers/bats_helper

SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md"

@test "eval-harness: skill file exists" {
    [ -f "$SKILL_FILE" ]
}

@test "eval-harness: skill has valid frontmatter delimiter" {
    has_frontmatter_delimiter "$SKILL_FILE"
}

@test "eval-harness: skill has name field" {
    has_frontmatter_field "$SKILL_FILE" "name"
}

@test "eval-harness: skill has description field" {
    has_frontmatter_field "$SKILL_FILE" "description"
}

@test "eval-harness: skill name is eval-harness" {
    grep -q "^name: eval-harness$" "$SKILL_FILE"
}

@test "eval-harness: skill description starts with Use when" {
    grep -q "^description: Use when" "$SKILL_FILE"
}

@test "eval-harness: skill documents worktree isolation" {
    grep -qi "worktree" "$SKILL_FILE"
}

@test "eval-harness: skill documents parallel subagents" {
    grep -qi "parallel" "$SKILL_FILE"
}

@test "eval-harness: skill documents model grader" {
    grep -qi "model grader\|judge" "$SKILL_FILE"
}

@test "eval-harness: skill documents code grader" {
    grep -qi "code grader\|PASS/FAIL\|bats" "$SKILL_FILE"
}

@test "eval-harness: skill documents VARIANT_A and VARIANT_B input" {
    grep -q "VARIANT_A" "$SKILL_FILE"
    grep -q "VARIANT_B" "$SKILL_FILE"
}

@test "eval-harness: skill documents winner output" {
    grep -qi "winner\|Verdict\|Recommendation" "$SKILL_FILE"
}

@test "eval-harness: skill documents tie as possible outcome" {
    grep -qi "tie\|Tie" "$SKILL_FILE"
}

@test "eval-harness: skill documents anonymization" {
    grep -qi "Option 1\|Option 2\|anon" "$SKILL_FILE"
}

@test "eval-harness: skill documents cleanup" {
    grep -qi "clean up\|cleanup" "$SKILL_FILE"
}
