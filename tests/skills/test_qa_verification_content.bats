#!/usr/bin/env bats

load '../helpers/bats_helper'

setup() {
  export QA_SKILL_MD="${BATS_TEST_DIRNAME}/../../plugins/me/skills/qa/SKILL.md"
  export QA_TEMPLATE_MD="${BATS_TEST_DIRNAME}/../../plugins/me/skills/qa/templates/qa-report-template.md"

  if [[ ! -f "$QA_SKILL_MD" ]]; then
    skip "qa SKILL.md not found"
  fi

  if [[ ! -f "$QA_TEMPLATE_MD" ]]; then
    skip "qa report template not found"
  fi
}

@test "qa SKILL.md describes implementation verification" {
  grep -q 'implementation verifier' "$QA_SKILL_MD"
  grep -q 'checks whether a feature or change behaves correctly in context' "$QA_SKILL_MD"
}

@test "qa SKILL.md includes verdict-first outcomes" {
  grep -q '\*\*PASS\*\*' "$QA_SKILL_MD"
  grep -q '\*\*PARTIAL\*\*' "$QA_SKILL_MD"
  grep -q '\*\*FAIL\*\*' "$QA_SKILL_MD"
}

@test "qa SKILL.md includes scope source rules" {
  grep -q 'Scope source: plan' "$QA_SKILL_MD"
  grep -q 'Scope source: branch' "$QA_SKILL_MD"
  grep -q 'Scope source: user override' "$QA_SKILL_MD"
}

@test "qa SKILL.md keeps /ship boundaries explicit" {
  grep -q 'Those belong to `/ship`.' "$QA_SKILL_MD"
  grep -q 'rollout readiness' "$QA_SKILL_MD"
  grep -q 'rollback readiness' "$QA_SKILL_MD"
  grep -q 'monitoring readiness' "$QA_SKILL_MD"
}

@test "qa SKILL.md no longer centers bug hunting" {
  run grep -q 'find bugs' "$QA_SKILL_MD"
  [ "$status" -ne 0 ]
}

@test "qa report template is verdict-first" {
  grep -q '^## Verdict:' "$QA_TEMPLATE_MD"
  grep -q '^## Scope$' "$QA_TEMPLATE_MD"
  grep -q '^## Verification Summary$' "$QA_TEMPLATE_MD"
  grep -q '^## Failed / Incomplete Scenarios$' "$QA_TEMPLATE_MD"
  grep -q '^## Evidence$' "$QA_TEMPLATE_MD"
  grep -q '^## Issues$' "$QA_TEMPLATE_MD"
  grep -q '^## Next Actions$' "$QA_TEMPLATE_MD"
}
