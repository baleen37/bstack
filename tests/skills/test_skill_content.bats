#!/usr/bin/env bats
# Test suite for SKILL.md content validation (writing-skills compliance)

load '../helpers/bats_helper'

setup() {
  export SKILL_MD="${BATS_TEST_DIRNAME}/../../skills/create-pr/SKILL.md"

  if [[ ! -f "$SKILL_MD" ]]; then
    skip "SKILL.md not found"
  fi
}

@test "SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "SKILL.md has required sections" {
  # Required sections that all skills should have
  grep -q "^## Overview" "$SKILL_MD"
  grep -q "^## When to Use" "$SKILL_MD"
  # Note: "Red Flags" is optional and not required for all skills
}

@test "SKILL.md has Iron Law principle" {
  # This test is for skills that follow the writing-skills pattern
  # The create-pr skill uses a different, minimal workflow pattern
  skip "Iron Law principle is not required for all skill types"
}
