#!/usr/bin/env bats
# Tests for eval-harness (EDD framework) and variant-compare (A/B comparison)

load ../helpers/bats_helper

SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md"
VARIANT_FILE="${PROJECT_ROOT}/plugins/me/skills/variant-compare/SKILL.md"

# eval-harness: EDD (Eval-Driven Development) framework
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

@test "eval-harness: skill documents EDD philosophy" {
    grep -qi "eval-driven development\|EDD" "$SKILL_FILE"
}

@test "eval-harness: skill documents capability evals" {
    grep -qi "capability eval" "$SKILL_FILE"
}

@test "eval-harness: skill documents regression evals" {
    grep -qi "regression eval" "$SKILL_FILE"
}

@test "eval-harness: skill documents model grader" {
    grep -qi "model.based grader\|model grader\|judge" "$SKILL_FILE"
}

@test "eval-harness: skill documents code grader" {
    grep -qi "code.based grader\|code grader\|PASS/FAIL" "$SKILL_FILE"
}

@test "eval-harness: skill documents pass@k metrics" {
    grep -q "pass@k\|pass@1\|pass@3" "$SKILL_FILE"
}

# variant-compare: A/B comparison (renamed from old eval-harness)
@test "variant-compare: skill file exists" {
    [ -f "$VARIANT_FILE" ]
}

@test "variant-compare: skill has valid frontmatter" {
    has_frontmatter_delimiter "$VARIANT_FILE"
    has_frontmatter_field "$VARIANT_FILE" "name"
    has_frontmatter_field "$VARIANT_FILE" "description"
}

@test "variant-compare: skill name is variant-compare" {
    grep -q "^name: variant-compare$" "$VARIANT_FILE"
}

@test "variant-compare: skill documents worktree isolation" {
    grep -qi "worktree" "$VARIANT_FILE"
}

@test "variant-compare: skill documents parallel subagents" {
    grep -qi "parallel" "$VARIANT_FILE"
}

@test "variant-compare: skill documents VARIANT_A and VARIANT_B" {
    grep -q "VARIANT_A" "$VARIANT_FILE"
    grep -q "VARIANT_B" "$VARIANT_FILE"
}

@test "variant-compare: skill documents anonymization" {
    grep -qi "Option 1\|Option 2\|anon" "$VARIANT_FILE"
}

@test "variant-compare: skill documents cleanup" {
    grep -qi "clean up\|cleanup" "$VARIANT_FILE"
}
