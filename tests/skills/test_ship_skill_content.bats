#!/usr/bin/env bats

load '../helpers/bats_helper'

setup() {
  export SHIP_SKILL_MD="${BATS_TEST_DIRNAME}/../../plugins/me/skills/ship/SKILL.md"

  if [[ ! -f "$SHIP_SKILL_MD" ]]; then
    skip "ship SKILL.md not found"
  fi
}

@test "ship SKILL.md exists" {
  [ -f "$SHIP_SKILL_MD" ]
}

@test "ship SKILL.md defines ship frontmatter name" {
  grep -q '^name: ship$' "$SHIP_SKILL_MD"
}

@test "ship SKILL.md describes readiness gate, not deploy execution" {
  grep -q 'launch gate, not a deploy executor' "$SHIP_SKILL_MD"
  grep -q 'Do not invent or run deploy commands' "$SHIP_SKILL_MD"
}

@test "ship SKILL.md includes required output sections" {
  grep -q '^### Decision$' "$SHIP_SKILL_MD"
  grep -q '^### Blocking issues$' "$SHIP_SKILL_MD"
  grep -q '^### Warnings$' "$SHIP_SKILL_MD"
  grep -q '^### Readiness by area$' "$SHIP_SKILL_MD"
  grep -q '^### Next actions$' "$SHIP_SKILL_MD"
}

@test "ship SKILL.md includes all readiness outcomes" {
  grep -q '\*\*Ready\*\*' "$SHIP_SKILL_MD"
  grep -q '\*\*Conditionally ready\*\*' "$SHIP_SKILL_MD"
  grep -q '\*\*Not ready\*\*' "$SHIP_SKILL_MD"
}
