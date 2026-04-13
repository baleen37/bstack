#!/usr/bin/env bats
# Test suite for harness-eval related skills

load '../helpers/bats_helper'

# eval-harness skill tests
@test "eval-harness SKILL.md exists" {
  [ -f "${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md" ]
}

@test "eval-harness has valid frontmatter" {
  local file="${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md"
  head -1 "$file" | grep -q "^---"
  grep -q "^name: eval-harness" "$file"
  grep -q "^description:" "$file"
}

@test "eval-harness contains EDD content" {
  grep -q "eval-driven development\|EDD" "${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md"
}

# variant-compare skill tests (renamed from old eval-harness)
@test "variant-compare SKILL.md exists" {
  [ -f "${PROJECT_ROOT}/plugins/me/skills/variant-compare/SKILL.md" ]
}

@test "variant-compare has valid frontmatter" {
  local file="${PROJECT_ROOT}/plugins/me/skills/variant-compare/SKILL.md"
  head -1 "$file" | grep -q "^---"
  grep -q "^name: variant-compare" "$file"
  grep -q "^description:" "$file"
}

# harness-audit skill tests
@test "harness-audit SKILL.md exists" {
  [ -f "${PROJECT_ROOT}/plugins/me/skills/harness-audit/SKILL.md" ]
}

@test "harness-audit has valid frontmatter" {
  local file="${PROJECT_ROOT}/plugins/me/skills/harness-audit/SKILL.md"
  head -1 "$file" | grep -q "^---"
  grep -q "^name: harness-audit" "$file"
  grep -q "^description:" "$file"
}

# harness-audit.js script tests
@test "harness-audit.js exists" {
  [ -f "${PROJECT_ROOT}/scripts/harness-audit.js" ]
}

@test "harness-audit.js runs without error" {
  run node "${PROJECT_ROOT}/scripts/harness-audit.js" --format text
  [ "$status" -eq 0 ]
}

@test "harness-audit.js json output is valid JSON" {
  run node "${PROJECT_ROOT}/scripts/harness-audit.js" --format json
  [ "$status" -eq 0 ]
  echo "$output" | node -e "JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'))"
}

@test "harness-audit.js supports scope argument" {
  run node "${PROJECT_ROOT}/scripts/harness-audit.js" hooks --format text
  [ "$status" -eq 0 ]
}
