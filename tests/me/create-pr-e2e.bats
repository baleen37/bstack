#!/usr/bin/env bats
# create-pr e2e test - intentionally failing to test CI recovery flow

@test "create-pr: wait-for-merge script exists and is executable" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  [ -f "$script" ]
  [ -x "$script" ]
}

@test "fix-pr: skill exists under the new name" {
  local skill="${BATS_TEST_DIRNAME}/../../plugins/me/skills/fix-pr/SKILL.md"

  [ -f "$skill" ]
}
