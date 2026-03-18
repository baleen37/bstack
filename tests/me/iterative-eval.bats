#!/usr/bin/env bats

load ../helpers/bats_helper

SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/iterative-eval/SKILL.md"

@test "iterative-eval: skill file exists" {
    [ -f "$SKILL_FILE" ]
}

@test "iterative-eval: skill has valid frontmatter delimiter" {
    has_frontmatter_delimiter "$SKILL_FILE"
}

@test "iterative-eval: skill has name field" {
    has_frontmatter_field "$SKILL_FILE" "name"
}

@test "iterative-eval: skill has description field" {
    has_frontmatter_field "$SKILL_FILE" "description"
}

@test "iterative-eval: skill name is iterative-eval" {
    grep -q "^name: iterative-eval$" "$SKILL_FILE"
}

@test "iterative-eval: skill description starts with Use when" {
    grep -q "^description: Use when" "$SKILL_FILE"
}

@test "iterative-eval: skill documents iteration loop" {
    grep -qi "iteration\|iterative\|loop" "$SKILL_FILE"
}

@test "iterative-eval: skill documents one-change-at-a-time principle" {
    grep -qi "one change\|single change\|하나만" "$SKILL_FILE"
}

@test "iterative-eval: skill documents reference comparison" {
    grep -qi "reference\|gold standard\|baseline" "$SKILL_FILE"
}

@test "iterative-eval: skill documents parallel generation" {
    grep -qi "parallel" "$SKILL_FILE"
}

@test "iterative-eval: skill documents judge evaluation" {
    grep -qi "judge\|grader" "$SKILL_FILE"
}

@test "iterative-eval: skill documents anonymization" {
    grep -qi "Option 1\|Option 2\|anon" "$SKILL_FILE"
}

@test "iterative-eval: skill documents adoption decision" {
    grep -qi "adopt\|accept\|채택" "$SKILL_FILE"
}

@test "iterative-eval: skill documents dynamic next-change" {
    grep -qi "feedback\|diagnos\|next change\|gap" "$SKILL_FILE"
}

@test "iterative-eval: skill documents TARGET input" {
    grep -q "TARGET" "$SKILL_FILE"
}

@test "iterative-eval: skill documents REFERENCES input" {
    grep -q "REFERENCES" "$SKILL_FILE"
}

@test "iterative-eval: skill documents EVALS input" {
    grep -q "EVALS" "$SKILL_FILE"
}

@test "iterative-eval: skill documents stop condition" {
    grep -qi "stop\|exit\|termination\|종료" "$SKILL_FILE"
}
