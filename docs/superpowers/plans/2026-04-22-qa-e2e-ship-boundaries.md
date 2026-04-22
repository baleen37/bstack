# QA / E2E / Ship Boundary Clarification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the `qa`, `e2e`, and `ship` skill docs and their content tests so the boundary is explicit: `qa` is the default verification path, `e2e` is a narrower cross-boundary verification skill, and `ship` is a release-readiness gate.

**Architecture:** Keep the existing skill structure and implement this as a small test-first documentation change. First lock the approved boundary model into focused BATS content tests, then update only the affected `SKILL.md` sections to satisfy those tests. Do not add new references or refactor unrelated skill content.

**Tech Stack:** Markdown (`SKILL.md`), BATS, grep-based content assertions, existing frontmatter and plugin-loading tests

---

## File Structure

- Modify: `plugins/me/skills/qa/SKILL.md`
  Purpose: make `/qa` explicitly the default verification path and clarify its boundary with `/e2e` and `/ship`
- Modify: `plugins/me/skills/e2e/SKILL.md`
  Purpose: reposition `/e2e` as a narrower special-purpose verification skill, not a peer replacement for `/qa`
- Modify: `plugins/me/skills/ship/SKILL.md`
  Purpose: make `/ship` explicitly consume verification evidence instead of re-verifying feature behavior
- Modify: `tests/skills/test_qa_verification_content.bats`
  Purpose: lock in `/qa` as the default verification path and preserve `/ship` boundary assertions
- Create: `tests/skills/test_e2e_skill_content.bats`
  Purpose: add focused content coverage for `/e2e` boundary language
- Modify: `tests/skills/test_ship_skill_content.bats`
  Purpose: lock in `/ship` as a readiness gate that sits after `/qa` and optional `/e2e`

### Task 1: Lock the approved boundaries in BATS tests

**Files:**
- Modify: `tests/skills/test_qa_verification_content.bats`
- Create: `tests/skills/test_e2e_skill_content.bats`
- Modify: `tests/skills/test_ship_skill_content.bats`

- [ ] **Step 1: Add the new `/qa` boundary assertion**

Append this test to `tests/skills/test_qa_verification_content.bats` after the existing scope-source test:

```bash
@test "qa SKILL.md defines qa as the default verification path" {
  grep -q 'default verification path' "$QA_SKILL_MD"
  grep -q 'If cross-service or multi-layer flow integrity is the main risk, add `/e2e`.' "$QA_SKILL_MD"
}
```

- [ ] **Step 2: Create the new `/e2e` content test file**

Create `tests/skills/test_e2e_skill_content.bats` with this content:

```bash
#!/usr/bin/env bats

load '../helpers/bats_helper'

setup() {
  export E2E_SKILL_MD="${BATS_TEST_DIRNAME}/../../plugins/me/skills/e2e/SKILL.md"

  if [[ ! -f "$E2E_SKILL_MD" ]]; then
    skip "e2e SKILL.md not found"
  fi
}

@test "e2e SKILL.md defines e2e as special-purpose verification" {
  grep -q 'special-purpose verification skill' "$E2E_SKILL_MD"
  grep -q 'Default to `/qa`.' "$E2E_SKILL_MD"
}

@test "e2e SKILL.md positions e2e as narrower than qa" {
  grep -q 'does not replace general feature verification' "$E2E_SKILL_MD"
  grep -q 'default verification still belongs to `/qa`' "$E2E_SKILL_MD"
}

@test "e2e SKILL.md explains when to add e2e" {
  grep -q 'service boundary' "$E2E_SKILL_MD"
  grep -q 'multiple layers' "$E2E_SKILL_MD"
  grep -q 'external integration' "$E2E_SKILL_MD"
}
```

- [ ] **Step 3: Add the new `/ship` boundary assertion**

Append this test to `tests/skills/test_ship_skill_content.bats` after the existing readiness-gate test:

```bash
@test "ship SKILL.md consumes qa and e2e evidence instead of re-verifying behavior" {
  grep -q 'does not re-verify feature behavior' "$SHIP_SKILL_MD"
  grep -q '`/qa` provides default behavior verification' "$SHIP_SKILL_MD"
  grep -q '`/e2e` provides cross-boundary flow verification when needed' "$SHIP_SKILL_MD"
}
```

- [ ] **Step 4: Run the new focused tests to verify they fail before documentation changes**

Run:

```bash
bats tests/skills/test_qa_verification_content.bats tests/skills/test_e2e_skill_content.bats tests/skills/test_ship_skill_content.bats
```

Expected: FAIL. The new assertions should fail because the current `SKILL.md` files do not yet use the approved boundary wording.

### Task 2: Update the three skill docs to match the approved boundary model

**Files:**
- Modify: `plugins/me/skills/qa/SKILL.md`
- Modify: `plugins/me/skills/e2e/SKILL.md`
- Modify: `plugins/me/skills/ship/SKILL.md`
- Test: `tests/skills/test_qa_verification_content.bats`
- Test: `tests/skills/test_e2e_skill_content.bats`
- Test: `tests/skills/test_ship_skill_content.bats`

- [ ] **Step 1: Update `/qa` intro and boundary language**

Replace the opening section of `plugins/me/skills/qa/SKILL.md` through the end of `## What \`/qa\` verifies` with:

```md
# /qa: Scope → Verify → Report

You are an implementation verifier. `/qa` is the default verification path for checking whether a feature or change behaves correctly in context. It does not act as a release-readiness gate, and it does not fix code.

## What `/qa` verifies

Focus on the current work context:

- the intended golden path
- the most relevant edge cases
- obvious regressions near the changed behavior

Default to change-centered verification, not exhaustive QA.

`/qa` is the default verification path. If cross-service or multi-layer flow integrity is the main risk, add `/e2e`.
```

- [ ] **Step 2: Expand `/qa` boundaries so `/e2e` and `/ship` each have a clear role**

Replace the `## Boundaries with \`/ship\`` section in `plugins/me/skills/qa/SKILL.md` with:

```md
## Boundaries with `/e2e` and `/ship`

`/qa` is the default verification path for implementation behavior.

It does **not** replace `/e2e` when the main question is whether a full flow still connects across:
- a service boundary
- multiple layers
- an external integration

It does **not** decide:
- rollout readiness
- rollback readiness
- monitoring readiness
- release readiness

Those belong to `/ship`.
```

- [ ] **Step 3: Rewrite `/e2e` overview and decision section**

Replace the `## Overview` and `## When to Use` sections in `plugins/me/skills/e2e/SKILL.md` with:

```md
## Overview

`/e2e` is a special-purpose verification skill. It confirms that a complete user-visible flow still connects correctly across all touched components. Unit and integration tests verify parts; `/e2e` verifies the full path when the main risk lives at the boundary between those parts.

**Core principle:** If your change crosses a service boundary, multiple layers, or an external integration, verify the full path and not just the individual pieces.

## When to Use

Default to `/qa`. Add `/e2e` only when one or more of the following are true:

- the main risk is at a service boundary
- the flow crosses multiple layers
- an external integration changed

`/e2e` does not replace general feature verification. The default verification still belongs to `/qa`.

**Needs e2e:**
- Changes span 2+ services/components that communicate
- API contracts changed (request/response shape, endpoints)
- Data flows through multiple layers (API → service → DB → notification)
- External integrations changed (payment providers, email services, third-party APIs)

**Skip e2e:**
- Pure refactoring with no behavior change (confirmed by existing tests)
- Isolated utility functions with comprehensive unit tests
- Documentation-only changes
- Single-component changes fully covered by integration tests
```

- [ ] **Step 4: Add an explicit relationship section to `/e2e`**

Insert this section in `plugins/me/skills/e2e/SKILL.md` immediately after `## When to Use`:

```md
## Relationship to `/qa` and `/ship`

- `/qa` provides default behavior verification
- `/e2e` provides cross-boundary flow verification when needed
- `/ship` uses verification evidence to decide release readiness
```

- [ ] **Step 5: Make `/ship` explicitly consume verification evidence**

Insert this section in `plugins/me/skills/ship/SKILL.md` after `## What \`/ship\` does NOT do`:

```md
## Relationship to `/qa` and `/e2e`

- `/qa` provides default behavior verification
- `/e2e` provides cross-boundary flow verification when needed
- `/ship` consumes that verification evidence and judges release readiness

`/ship` does not re-verify feature behavior that belongs to `/qa` or `/e2e`.
```

Then replace the evidence bullets under `## Candidate under review` with:

```md
Use whatever evidence is available in the repository to understand scope:
- current branch state
- `main...HEAD` diff when available
- recent `/qa` or `/e2e` verification evidence
```

- [ ] **Step 6: Run the focused tests and verify they pass**

Run:

```bash
bats tests/skills/test_qa_verification_content.bats tests/skills/test_e2e_skill_content.bats tests/skills/test_ship_skill_content.bats
```

Expected: PASS. All three skill docs should now match the approved boundary model.

- [ ] **Step 7: Commit the documentation and focused test updates**

Run:

```bash
git add \
  plugins/me/skills/qa/SKILL.md \
  plugins/me/skills/e2e/SKILL.md \
  plugins/me/skills/ship/SKILL.md \
  tests/skills/test_qa_verification_content.bats \
  tests/skills/test_e2e_skill_content.bats \
  tests/skills/test_ship_skill_content.bats
git commit -m "docs(skills): clarify qa e2e ship boundaries"
```

### Task 3: Run regression checks for skill content and plugin conventions

**Files:**
- Test: `tests/frontmatter_tests.bats`
- Test: `tests/integration/plugin_loading.bats`
- Test: `tests/me/me-specific.bats`
- Test: `tests/skills/test_qa_verification_content.bats`
- Test: `tests/skills/test_e2e_skill_content.bats`
- Test: `tests/skills/test_ship_skill_content.bats`

- [ ] **Step 1: Run the regression suite**

Run:

```bash
bats \
  tests/frontmatter_tests.bats \
  tests/integration/plugin_loading.bats \
  tests/me/me-specific.bats \
  tests/skills/test_qa_verification_content.bats \
  tests/skills/test_e2e_skill_content.bats \
  tests/skills/test_ship_skill_content.bats
```

Expected: PASS. No frontmatter, plugin-loading, or skill-content regressions.

- [ ] **Step 2: If a regression fails, make the smallest possible fix in the already-touched files**

Apply this rule:

```text
- frontmatter delimiter/name/description failure → edit only the affected `SKILL.md` frontmatter
- qa content failure → edit only `plugins/me/skills/qa/SKILL.md` or `tests/skills/test_qa_verification_content.bats`
- e2e content failure → edit only `plugins/me/skills/e2e/SKILL.md` or `tests/skills/test_e2e_skill_content.bats`
- ship content failure → edit only `plugins/me/skills/ship/SKILL.md` or `tests/skills/test_ship_skill_content.bats`
- plugin-loading or me-specific failure unrelated to these files → stop and inspect before changing anything
```

- [ ] **Step 3: Re-run the same regression suite after any fix**

Run:

```bash
bats \
  tests/frontmatter_tests.bats \
  tests/integration/plugin_loading.bats \
  tests/me/me-specific.bats \
  tests/skills/test_qa_verification_content.bats \
  tests/skills/test_e2e_skill_content.bats \
  tests/skills/test_ship_skill_content.bats
```

Expected: PASS.
