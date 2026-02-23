#!/usr/bin/env bats
# Test suite for competitive-agents skill

load '../helpers/bats_helper'

setup() {
  export SKILL_MD="${BATS_TEST_DIRNAME}/../../plugins/me/skills/competitive-agents/SKILL.md"

  if [[ ! -f "$SKILL_MD" ]]; then
    skip "SKILL.md not found"
  fi
}

@test "competitive-agents SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "SKILL.md has valid frontmatter" {
  head -1 "$SKILL_MD" | grep -q "^---"
  grep -q "^name: competitive-agents" "$SKILL_MD"
  grep -q "^description:" "$SKILL_MD"
}

@test "SKILL.md has required sections" {
  grep -q "^## Overview" "$SKILL_MD"
  grep -q "^## When to Use" "$SKILL_MD"
}
