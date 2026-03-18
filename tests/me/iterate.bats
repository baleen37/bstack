#!/usr/bin/env bats

load ../helpers/bats_helper

SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/iterate/SKILL.md"

@test "iterate: skill file exists" {
    [ -f "$SKILL_FILE" ]
}

@test "iterate: skill has valid frontmatter delimiter" {
    has_frontmatter_delimiter "$SKILL_FILE"
}

@test "iterate: skill has name field" {
    has_frontmatter_field "$SKILL_FILE" "name"
}

@test "iterate: skill has description field" {
    has_frontmatter_field "$SKILL_FILE" "description"
}

@test "iterate: skill name is iterate" {
    grep -q "^name: iterate$" "$SKILL_FILE"
}

@test "iterate: skill description starts with Use when" {
    grep -q "^description: Use when" "$SKILL_FILE"
}

@test "iterate: skill documents one-change-at-a-time principle" {
    grep -qi "one change\|single change\|one at a time" "$SKILL_FILE"
}

@test "iterate: skill documents verification step" {
    grep -qi "verif\|validat\|check" "$SKILL_FILE"
}

@test "iterate: skill documents adopt or reject decision" {
    grep -qi "adopt\|reject\|accept\|revert" "$SKILL_FILE"
}

@test "iterate: skill documents feedback-driven next change" {
    grep -qi "feedback\|diagnos\|next change\|gap\|signal" "$SKILL_FILE"
}

@test "iterate: skill documents stop condition" {
    grep -qi "stop\|exit\|terminat" "$SKILL_FILE"
}

@test "iterate: skill is not limited to eval use case" {
    # Should mention multiple verification methods, not just A/B judge
    grep -qi "test\|build\|user" "$SKILL_FILE"
}

@test "iterate: skill documents iteration report" {
    grep -qi "report\|result\|summary" "$SKILL_FILE"
}
