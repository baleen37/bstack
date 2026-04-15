# me /ship Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `me` plugin `/ship` skill that behaves as a shipping readiness gate rather than a deploy executor.

**Architecture:** Implement `/ship` as a minimal Markdown skill with one always-loaded `SKILL.md` and one on-demand reference file for checklist details. Keep the behavior aligned with agent-skills: evaluate the current change set, report readiness as Ready / Conditionally ready / Not ready, and never infer or execute deploy commands.

**Tech Stack:** Markdown skill authoring, BATS tests, existing plugin/skill loading conventions

---

### Task 1: Create the `/ship` reference checklist

**Files:**
- Create: `plugins/me/skills/ship/references/ship-checklist.md`
- Test: `plugins/me/skills/ship/references/ship-checklist.md`

- [ ] **Step 1: Write the failing presence check mentally from the spec**

The spec requires an on-demand reference file with checklist examples for pre-launch, rollout, rollback, monitoring, plus blocker/warning examples. The file does not exist yet, so the expected first failure is simply “missing file at the exact path”.

- [ ] **Step 2: Create `ship-checklist.md` with the minimal required content**

Write `plugins/me/skills/ship/references/ship-checklist.md` with this content:

```markdown
# Ship Checklist

Reference material for `/ship`. Read this when you need concrete examples while assessing shipping readiness. This file supports the core skill; it does not change the `/ship` contract.

## Pre-launch checks

Use these to decide whether the change is basically ready to leave the branch:

- The change scope can be described in one or two sentences.
- The relevant tests or verification steps are named and have recent evidence.
- Any required review, approval, or human sign-off is explicit.
- Any launch notes or operator context are written down somewhere discoverable.

## Rollout readiness

Use these to assess whether the release can be introduced safely:

- A staged rollout is possible, or the change is clearly low-risk enough not to need one.
- A feature flag, kill switch, or config gate exists when exposure risk is meaningful.
- The change does not require an all-at-once cutover without justification.

## Rollback readiness

Use these to assess whether the team can recover quickly:

- A rollback path can be explained in plain language.
- Irreversible schema or data changes are identified explicitly.
- The first action to take during a bad launch is known.

## Monitoring readiness

Use these to assess whether post-launch behavior is observable:

- There is at least one success signal to watch.
- There is at least one failure signal to watch.
- The relevant logs, metrics, or alerts are named.
- The launch is not blind; someone could tell within minutes if it went wrong.

## Blocking issue examples

These usually mean `/ship` should report **Not ready**:

- No test or verification evidence is available.
- No rollback path can be described.
- Monitoring signals are completely unknown.
- Required QA or review has clearly not happened.

## Warning examples

These usually mean `/ship` should report **Conditionally ready** rather than **Ready**:

- The change is large and rollout strategy is weak.
- A feature flag would help but is not strictly required.
- Monitoring exists but the exact watchpoints are not written down.
- The launch can proceed, but only with explicit human attention.

## Suggested decision language

Use short, direct language:

- **Ready** — No blockers found. Basic rollout, rollback, and monitoring expectations are covered.
- **Conditionally ready** — No hard blocker, but the ship needs explicit follow-up before or during launch.
- **Not ready** — One or more critical gates are missing; shipping now would be unsafe.
```

- [ ] **Step 3: Verify the file exists and starts correctly**

Run: `test -f plugins/me/skills/ship/references/ship-checklist.md && sed -n '1,12p' plugins/me/skills/ship/references/ship-checklist.md`
Expected: output starts with `# Ship Checklist` and includes the sentence `Reference material for '/ship'`.

- [ ] **Step 4: Commit the reference file**

```bash
git add plugins/me/skills/ship/references/ship-checklist.md
git commit -m "feat(ship): add shipping checklist reference"
```

---

### Task 2: Create the core `/ship` skill

**Files:**
- Create: `plugins/me/skills/ship/SKILL.md`
- Test: `plugins/me/skills/ship/SKILL.md`

- [ ] **Step 1: Write the failing contract checklist from the spec**

Before writing the skill, verify the spec requirements that must appear in the file:

- readiness gate, not deploy executor
- non-goals mention no deploy inference/execution
- Decision / Blocking issues / Warnings / Readiness by area / Next actions output structure
- Ready / Conditionally ready / Not ready decisions
- instruction to consult `references/ship-checklist.md` when needed

The file does not exist yet, so this contract currently fails by absence.

- [ ] **Step 2: Create `SKILL.md` with the exact first version**

Write `plugins/me/skills/ship/SKILL.md` with this content:

```markdown
---
name: ship
description: Use when asked to "ship", "launch", "release", or "is this ready to go live?". Reviews the current change as a shipping candidate and reports readiness without executing deploy commands.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# /ship: Review shipping readiness

You are a shipping readiness reviewer. `/ship` is a launch gate, not a deploy executor.

## What `/ship` does

- Reviews the current change as a shipping candidate
- Identifies blockers and warnings
- Assesses rollout, rollback, and monitoring readiness
- Produces a short readiness report with next actions

## What `/ship` does NOT do

- Do not invent or run deploy commands
- Do not replace `/qa`
- Do not create or merge PRs
- Do not take ownership of versioning or release automation

## Candidate under review

Default to the current working change.

Use whatever evidence is available in the repository to understand scope:
- current branch state
- `main...HEAD` diff when available
- recent test or verification evidence

If the scope is unclear, say so and downgrade the decision.

## Required review areas

Review the change across these areas:

1. **Pre-launch** — Is the scope clear? Is there test or verification evidence? Is required review or operator context present?
2. **Rollout** — Could this be introduced safely? Is there a feature flag, kill switch, or another way to limit blast radius when appropriate?
3. **Rollback** — Could the team explain how to recover if the launch goes badly?
4. **Monitoring** — Are there logs, metrics, alerts, or explicit watchpoints that would reveal success or failure?

For concrete examples and decision patterns, read `ship/references/ship-checklist.md`.

## Decision rules

Choose one outcome:

- **Ready** — No blockers found. Basic rollout, rollback, and monitoring expectations are covered.
- **Conditionally ready** — Not blocked, but the launch needs explicit follow-up before or during release.
- **Not ready** — A critical gate is missing.

Default to **Not ready** when core evidence is missing.

## Output format

Always report using these sections:

### Decision

Ready / Conditionally ready / Not ready

### Blocking issues

List only items that must be resolved before shipping.

### Warnings

List risks that do not fully block launch.

### Readiness by area

- Pre-launch: pass / weak / fail
- Rollout: pass / weak / fail
- Rollback: pass / weak / fail
- Monitoring: pass / weak / fail

### Next actions

Give the smallest set of actions needed to improve readiness.

## Red flags

Do not mark a change as Ready if any of these are true:

- there is no test or verification evidence
- rollback is unknown
- monitoring signals are unknown
- required QA or review clearly has not happened

## Verification expectations

Ground every judgment in repository evidence. If you cannot verify a claim, say that directly and lower the readiness decision.
```

- [ ] **Step 3: Verify required sections exist**

Run: `grep -E '^name: ship$|^## What `/ship` does NOT do$|^### Decision$|^### Blocking issues$|^### Warnings$|^### Readiness by area$|^### Next actions$' plugins/me/skills/ship/SKILL.md`
Expected: matches for all required headings and the `name: ship` frontmatter line.

- [ ] **Step 4: Verify the reference path is spelled correctly**

Run: `grep -n 'ship/references/ship-checklist.md' plugins/me/skills/ship/SKILL.md`
Expected: one matching line pointing to `ship/references/ship-checklist.md`.

- [ ] **Step 5: Commit the core skill**

```bash
git add plugins/me/skills/ship/SKILL.md
git commit -m "feat(ship): add shipping readiness skill"
```

---

### Task 3: Extend plugin tests to cover `/ship`

**Files:**
- Modify: `tests/me/me-specific.bats`
- Create: `tests/skills/test_ship_skill_content.bats`
- Test: `tests/me/me-specific.bats`
- Test: `tests/skills/test_ship_skill_content.bats`

- [ ] **Step 1: Add a presence test in `tests/me/me-specific.bats`**

Append these tests after the existing create-pr skill tests:

```bash
@test "me: ship skill exists with required files" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/ship/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/ship/references/ship-checklist.md" ]
}

@test "me: ship skill has proper frontmatter" {
    local skill_file="${PROJECT_ROOT}/plugins/me/skills/ship/SKILL.md"
    has_frontmatter_delimiter "$skill_file"
    has_frontmatter_field "$skill_file" "name"
    has_frontmatter_field "$skill_file" "description"
}
```

- [ ] **Step 2: Add focused content tests for `/ship`**

Create `tests/skills/test_ship_skill_content.bats` with this content:

```bash
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
```

- [ ] **Step 3: Run the new `/ship` tests**

Run: `bats tests/me/me-specific.bats tests/skills/test_ship_skill_content.bats`
Expected: all `/ship` assertions PASS.

- [ ] **Step 4: Commit the tests**

```bash
git add tests/me/me-specific.bats tests/skills/test_ship_skill_content.bats
git commit -m "test(ship): add ship skill coverage"
```

---

### Task 4: Run repo-level verification for the new skill

**Files:**
- Modify: none
- Test: `tests/me/me-specific.bats`
- Test: `tests/skills/test_ship_skill_content.bats`
- Test: `tests/frontmatter_tests.bats`
- Test: `tests/integration/plugin_loading.bats`

- [ ] **Step 1: Run the targeted structural test suites**

Run: `bats tests/frontmatter_tests.bats tests/integration/plugin_loading.bats tests/me/me-specific.bats tests/skills/test_ship_skill_content.bats`
Expected: PASS. The new skill should satisfy frontmatter and plugin-loading conventions.

- [ ] **Step 2: If a failure mentions a missing heading or frontmatter field, fix only the minimal relevant file**

Use this decision table:

- If the failure mentions `has_frontmatter_field` or delimiter checks, edit `plugins/me/skills/ship/SKILL.md` frontmatter only.
- If the failure mentions missing file paths, create or rename only the missing `/ship` files.
- If the failure mentions specific text assertions, update only the exact tested wording in `plugins/me/skills/ship/SKILL.md` or `tests/skills/test_ship_skill_content.bats`.

Do not broaden scope beyond the `/ship` skill and its direct tests.

- [ ] **Step 3: Re-run the same targeted suites until they pass**

Run: `bats tests/frontmatter_tests.bats tests/integration/plugin_loading.bats tests/me/me-specific.bats tests/skills/test_ship_skill_content.bats`
Expected: PASS with no `/ship`-related failures.

- [ ] **Step 4: Run the project test entrypoint**

Run: `bash tests/run-all-tests.sh`
Expected: PASS. The repository-wide BATS runner completes without regressions from the new skill.

- [ ] **Step 5: Commit the final verified state**

```bash
git add plugins/me/skills/ship/SKILL.md plugins/me/skills/ship/references/ship-checklist.md tests/me/me-specific.bats tests/skills/test_ship_skill_content.bats
git commit -m "feat(ship): add shipping readiness skill"
```

---

## Spec Coverage Check

- **Goal / readiness gate:** Covered by Task 2.
- **No deploy inference/execution:** Covered by Task 2 content assertions and Task 3 tests.
- **Reference checklist file:** Covered by Task 1.
- **Decision + blocker/warning + readiness-area output contract:** Covered by Task 2 and Task 3.
- **`/qa` and `/create-pr` role boundaries:** Covered by Task 2 wording.
- **Repository conventions and regression safety:** Covered by Task 4.

## Self-Review Notes

- Placeholder scan completed; no unresolved marker text remains.
- File paths are exact and match current repository structure.
- Later test tasks reference the same names introduced in Task 2: `ship`, `Decision`, `Blocking issues`, `Warnings`, `Readiness by area`, `Next actions`.
- Scope stays intentionally narrow: one new skill, one reference file, and direct tests only.
