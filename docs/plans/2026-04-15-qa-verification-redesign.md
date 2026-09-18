# QA Verification Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework `/qa` so it validates whether an implementation behaves correctly in context, using verdict-first output (`PASS / PARTIAL / FAIL`) instead of bug-hunt-first reporting.

**Architecture:** Keep the existing lean `/qa` file structure (`SKILL.md`, reference docs, report template) but change the contract: `SKILL.md` becomes verification-first, the report template moves verdict and scope to the top, and test coverage checks the new boundaries with `/ship`. Scope resolution should prefer plan context, then branch context, while still allowing explicit user override to take precedence when directly specified.

**Tech Stack:** Markdown skill authoring, BATS tests, existing me plugin conventions

---

### Task 1: Rewrite `plugins/me/skills/qa/SKILL.md` as a verification-first skill

**Files:**
- Modify: `plugins/me/skills/qa/SKILL.md`
- Test: `plugins/me/skills/qa/SKILL.md`

- [ ] **Step 1: Write the failing contract checklist from the spec**

Before editing, list the new requirements this file must express:

- `/qa` is implementation verification, not bug-hunt-first QA
- verdict-first output: `PASS / PARTIAL / FAIL`
- scope resolution includes `plan`, `branch`, and explicit `user override`
- verification model is golden path + key edge case + obvious regression
- `/qa` must not claim `/ship` responsibilities like rollout / rollback / monitoring readiness
- transition prompt should be verdict-based rather than issue-count-based

The current `plugins/me/skills/qa/SKILL.md` fails this contract because it still says “find bugs” and “You are a QA engineer” and centers issue reporting.

- [ ] **Step 2: Replace `plugins/me/skills/qa/SKILL.md` with the new verification-first content**

Replace the entire file with:

```markdown
---
name: qa
description: Use when asked to "qa", "verify this", "does this implementation work?", or "test this feature". Verifies the current implementation in context and reports `PASS`, `PARTIAL`, or `FAIL` with evidence.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
---

# /qa: Scope → Verify → Report

You are an implementation verifier. `/qa` checks whether a feature or change behaves correctly in context. It does not act as a release-readiness gate and it does not fix code.

## What `/qa` verifies

Focus on the current work context:

- the intended golden path
- the most relevant edge cases
- obvious regressions near the changed behavior

Default to change-centered verification, not exhaustive QA.

## Scope resolution

Decide scope in this order unless the user explicitly overrides it:

1. **Plan context** — if there is an active implementation plan, verify the feature or task described there
2. **Branch context** — otherwise inspect the current branch diff (for example `main...HEAD`) and verify the affected behavior
3. **User hint** — if the user gives extra guidance without explicit override, use it to refine the current plan or branch context, but do not treat it as a separate scope source

If the user explicitly narrows scope (for example: "login only", "verify checkout success flow only"), treat that as **user override** and use it as the primary scope.

Always report the scope source as one of:
- `Scope source: plan`
- `Scope source: branch`
- `Scope source: user override`

## Verification flow

### Phase 1: Scope

1. Identify the feature, scenario, or change under verification
2. State the scope source: `plan`, `branch`, or `user override`
3. Define a compact verification set:
   - one golden path
   - one or more key edge cases
   - one or more obvious regression checks when relevant

For project-type-specific verification ideas, read `references/exploration-guide.md`.

### Phase 2: Verify

Execute the verification plan.

Create output directory: `mkdir -p .qa/reports/evidence`

For each verified scenario:
1. Run the scenario
2. Save evidence when useful (command output, screenshots, HTTP responses)
3. Record whether it passed, failed, or remains incomplete

Web projects: use `/browse` for browser automation.

## Boundaries with `/ship`

`/qa` verifies implementation behavior. It does **not** decide:
- rollout readiness
- rollback readiness
- monitoring readiness
- release readiness

Those belong to `/ship`.

## Verdicts

Always choose one:

- **PASS** — the scoped implementation behaves correctly; no blocking behavior issues were found in verified scenarios
- **PARTIAL** — the implementation mostly works, but at least one important scenario failed, stayed incomplete, or remains uncertain
- **FAIL** — a core scenario failed or the implementation clearly does not meet the intended behavior

## Report structure

Use the template from `templates/qa-report-template.md`. The report must include:

1. Verdict
2. Scope
3. Verification summary
4. Failed / incomplete scenarios
5. Evidence
6. Issues
7. Next actions

Use `references/issue-taxonomy.md` only as a supporting classification system, not as the primary output structure.

## Transition

After the report:

> "검증 결과는 PASS/PARTIAL/FAIL입니다. 수정 후 다시 검증하시겠습니까?"
> A) Subagent-driven — 수정 후 재검증 (`superpowers:subagent-driven-development`)
> B) Inline — 순차 수정 후 재검증 (`superpowers:executing-plans`)
> C) 아니오 — 리포트만 남기고 종료

If C: end.
```

- [ ] **Step 3: Run a focused content check and verify the old bug-hunt framing is gone**

Run:

```bash
grep -nE '^name: qa$|PASS|PARTIAL|FAIL|Scope source: plan|Scope source: branch|Scope source: user override|rollout readiness|rollback readiness|monitoring readiness' plugins/me/skills/qa/SKILL.md && ! grep -q 'find bugs' plugins/me/skills/qa/SKILL.md
```

Expected:
- matches for `name: qa`, `PASS`, `PARTIAL`, `FAIL`, and each scope source line
- the command exits 0 because `find bugs` no longer appears in the file

- [ ] **Step 4: Commit the verification-first skill contract**

```bash
git add plugins/me/skills/qa/SKILL.md
git commit -m "refactor(qa): make skill verification-first"
```

---

### Task 2: Rebuild the QA report template around verdict-first output

**Files:**
- Modify: `plugins/me/skills/qa/templates/qa-report-template.md`
- Test: `plugins/me/skills/qa/templates/qa-report-template.md`

- [ ] **Step 1: Write the failing template checklist from the spec**

The spec requires the report order to become:
1. Verdict
2. Scope
3. Verification summary
4. Failed / incomplete scenarios
5. Evidence
6. Issues
7. Next actions

The current template fails this because it starts with Health Score and issue-centric sections instead of verdict and scope.

- [ ] **Step 2: Replace the template with the new verdict-first structure**

Replace the entire file with:

```markdown
# QA Verification Report: {PROJECT_NAME}

## Verdict: {PASS | PARTIAL | FAIL}

## Scope

- **Target:** {what was verified}
- **Scope source:** {plan | branch | user override}
- **Branch:** {BRANCH}
- **Commit:** {COMMIT_SHA}
- **Duration:** {DURATION}

## Verification Summary

### Golden path
- {scenario} — PASS / PARTIAL / FAIL

### Key edge cases
- {scenario} — PASS / PARTIAL / FAIL

### Obvious regressions
- {scenario} — PASS / PARTIAL / FAIL

## Failed / Incomplete Scenarios

- {scenario} — {why it failed or remains incomplete}

## Evidence

- {path to log, screenshot, or HTTP response}
- {key command output or reproduction note}

## Issues

### ISSUE-001: {Short title}

| Field | Value |
|-------|-------|
| **Severity** | critical / high / medium / low |
| **Category** | correctness / error-handling / edge-case / usability / performance / security / documentation |
| **Location** | {where it was observed} |

**Description:** {What is wrong and why it matters to the verdict.}

## Next Actions

- {what to fix next}
- {what to re-verify next}
- {what verification gaps remain before handing off to `/ship`}
```

- [ ] **Step 3: Verify the new section order exactly**

Run:

```bash
grep -nE '^## Verdict:|^## Scope$|^## Verification Summary$|^## Failed / Incomplete Scenarios$|^## Evidence$|^## Issues$|^## Next Actions$' plugins/me/skills/qa/templates/qa-report-template.md
```

Expected:
- seven matches in the exact top-to-bottom order required by the spec

- [ ] **Step 4: Commit the template redesign**

```bash
git add plugins/me/skills/qa/templates/qa-report-template.md
git commit -m "refactor(qa): make report template verdict-first"
```

---

### Task 3: Add regression tests for the new `/qa` contract

**Files:**
- Create: `tests/skills/test_qa_verification_content.bats`
- Test: `tests/skills/test_qa_verification_content.bats`

- [ ] **Step 1: Create a focused BATS file for the new `/qa` behavior contract**

Create `tests/skills/test_qa_verification_content.bats` with this content:

```bash
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
```

- [ ] **Step 2: Run the focused `/qa` content tests**

Run:

```bash
bats tests/skills/test_qa_verification_content.bats
```

Expected:
- all tests PASS

- [ ] **Step 3: Commit the new `/qa` contract tests**

```bash
git add tests/skills/test_qa_verification_content.bats
git commit -m "test(qa): cover verification-first contract"
```

---

### Task 4: Run compatibility and repository verification

**Files:**
- Modify: none
- Test: `tests/skills/test_qa_verification_content.bats`
- Test: `tests/skills/test_skill_content.bats`
- Test: `tests/frontmatter_tests.bats`
- Test: `tests/integration/plugin_loading.bats`
- Test: `tests/run-all-tests.sh`

- [ ] **Step 1: Run focused compatibility suites for QA and shared skill loading**

Run:

```bash
bats tests/skills/test_qa_verification_content.bats tests/skills/test_skill_content.bats tests/frontmatter_tests.bats tests/integration/plugin_loading.bats
```

Expected:
- PASS
- no new frontmatter or plugin-loading regressions

- [ ] **Step 2: If a failure occurs, fix only the minimum relevant file**

Use this table:

- missing frontmatter / delimiters → edit only `plugins/me/skills/qa/SKILL.md`
- missing report headings → edit only `plugins/me/skills/qa/templates/qa-report-template.md`
- broken test wording → edit only `tests/skills/test_qa_verification_content.bats`
- plugin loading / path regression → edit only the exact path or heading that failed

Do not broaden scope beyond `/qa` and direct compatibility checks.

- [ ] **Step 3: Re-run the same compatibility suites until they pass**

Run:

```bash
bats tests/skills/test_qa_verification_content.bats tests/skills/test_skill_content.bats tests/frontmatter_tests.bats tests/integration/plugin_loading.bats
```

Expected:
- PASS

- [ ] **Step 4: Run the repository test entrypoint**

Run:

```bash
bash tests/run-all-tests.sh
```

Expected:
- PASS

- [ ] **Step 5: Commit the final verified `/qa` redesign**

```bash
git add plugins/me/skills/qa/SKILL.md plugins/me/skills/qa/templates/qa-report-template.md tests/skills/test_qa_verification_content.bats
git commit -m "refactor(qa): redesign verification flow"
```

---

## Spec Coverage Check

- **Implementation verification role:** covered by Task 1.
- **Verdict-first output (`PASS / PARTIAL / FAIL`):** covered by Task 1 and Task 2.
- **Scope rules with plan / branch / explicit user override:** covered by Task 1 and tested in Task 3.
- **Golden path / edge case / obvious regression model:** covered by Task 1.
- **Boundary with `/ship`:** covered by Task 1 and tested in Task 3.
- **Template restructuring:** covered by Task 2.
- **Compatibility and repo-level verification:** covered by Task 4.

## Self-Review Notes

- No placeholders remain.
- File paths are exact and match the current repository structure.
- The plan stays narrow: only `/qa` skill contract, report template, and direct tests change.
- Existing supporting references (`issue-taxonomy.md`, `exploration-guide.md`) are intentionally reused rather than reworked in this pass.
