# Lifecycle Skills Upstream Alignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strengthen the existing `test`, `review`, and `ship` skills with upstream-aligned test/review/launch practices
while preserving the current bstack lifecycle workflow.

**Architecture:** Keep the existing `plugins/me/skills/test`, `plugins/me/skills/review`, and `plugins/me/skills/ship`
skill entry points. Add clearer workflow gates and cross-links to existing local skills instead of adding duplicate
upstream skills.

**Tech Stack:** Markdown skill files with YAML frontmatter, bstack `me` plugin lifecycle documentation,
Bun/BATS/pre-commit verification.

---

## File Structure

- Modify: `plugins/me/skills/test/SKILL.md` — add stronger TDD, focused testing, browser/runtime verification, and
  evidence rules.
- Modify: `plugins/me/skills/review/SKILL.md` — add severity criteria, simplification guidance, security escalation, and
  review evidence rules.
- Modify: `plugins/me/skills/ship/SKILL.md` — add stronger production readiness gates for CI, observability, staged
  rollout, rollback, and explicit NO-GO defaults.
- Modify: `plugins/me/README.md` — only if the skill descriptions need small wording updates after the three skill files
  change.

### Task 1: Strengthen `/test`

**Files:**

- Modify: `plugins/me/skills/test/SKILL.md`

- [ ] **Step 1: Read the existing test skill**

Run: `sed -n '1,220p' plugins/me/skills/test/SKILL.md`
Expected: Existing `/test` workflow is visible and still uses YAML frontmatter with `disable-model-invocation: true`.

- [ ] **Step 2: Update testing principles**

Replace the short preference list with explicit principles covering failing tests first, observable outcomes, focused
commands, browser/runtime checks for UI, and exact evidence.

- [ ] **Step 3: Add workflow gates**

Ensure the workflow says bugs should be reproduced before fixing when feasible, implementation should be minimal,
focused tests run before broader suites, and final output includes commands and results.

- [ ] **Step 4: Link existing local skills**

Keep the skill local-first by linking `debugging-and-error-recovery`, `browse`, `qa`, `verify`, and `e2e` instead of
adding duplicate upstream skills.

- [ ] **Step 5: Verify markdown shape**

Run: `grep -n "^## \|^# /test\|debugging-and-error-recovery\|browse\|qa\|verify\|e2e" plugins/me/skills/test/SKILL.md`
Expected: The updated sections and local skill links are present.

### Task 2: Strengthen `/review`

**Files:**

- Modify: `plugins/me/skills/review/SKILL.md`

- [ ] **Step 1: Read the existing review skill**

Run: `sed -n '1,240p' plugins/me/skills/review/SKILL.md`
Expected: Existing `/review` workflow and final report format are visible.

- [ ] **Step 2: Add review severity rules**

Add clear definitions for blockers and non-blocking suggestions so review output does not mix correctness risks with
style preferences.

- [ ] **Step 3: Add simplification and security escalation**

Add rules to flag unnecessary abstraction, large speculative changes, secrets, auth/authz, injection, dependency/config
risks, and to use `security-auditor` for sensitive changes.

- [ ] **Step 4: Preserve subagent fan-out guidance**

Keep `code-reviewer`, `security-auditor`, and `test-engineer` guidance, but make their responsibilities more precise and
findings-only.

- [ ] **Step 5: Verify markdown shape**

Run: `grep -n "Severity\|Blocking\|Non-blocking\|security-auditor\|test-engineer\|code-reviewer"
plugins/me/skills/review/SKILL.md`
Expected: Severity rules, output format, and subagent references are present.

### Task 3: Strengthen `/ship`

**Files:**

- Modify: `plugins/me/skills/ship/SKILL.md`

- [ ] **Step 1: Read the existing ship skill**

Run: `sed -n '1,260p' plugins/me/skills/ship/SKILL.md`
Expected: Existing fan-out launch review and GO/NO-GO output format are visible.

- [ ] **Step 2: Add launch readiness gates**

Add explicit checks for CI status, migrations/config/env, feature flags, monitoring, rollback trigger/procedure, staged
rollout, documentation, and post-launch verification.

- [ ] **Step 3: Tighten GO/NO-GO defaults**

Ensure any Critical security finding, failing required test/build/check, missing rollback plan, or unverifiable
production risk defaults to NO-GO unless the user explicitly accepts the risk.

- [ ] **Step 4: Preserve parallel specialist fan-out**

Keep the requirement that `code-reviewer`, `security-auditor`, and `test-engineer` run in parallel for non-trivial
production-bound changes.

- [ ] **Step 5: Verify markdown shape**

Run: `grep -n "GO | NO-GO\|rollback\|monitoring\|staged\|CI\|security-auditor\|test-engineer"
plugins/me/skills/ship/SKILL.md`
Expected: Decision output, rollback, launch gates, and specialist references are present.

### Task 4: Documentation and repository verification

**Files:**

- Modify only if needed: `plugins/me/README.md`

- [ ] **Step 1: Check whether README descriptions still match**

Run: `grep -n "test\|review\|ship\|shipping-and-launch\|ci-cd-and-automation" plugins/me/README.md`
Expected: Existing lifecycle descriptions still accurately describe the updated skills.

- [ ] **Step 2: Update README only for factual mismatch**

If a description is stale, make the smallest wording-only edit. If descriptions remain accurate, do not edit README.

- [ ] **Step 3: Run focused markdown validation**

Run: `pre-commit run markdownlint --files plugins/me/skills/test/SKILL.md plugins/me/skills/review/SKILL.md
plugins/me/skills/ship/SKILL.md docs/superpowers/plans/2026-05-12-lifecycle-skills-upstream-alignment.md`
Expected: PASS, or only actionable markdown issues that should be fixed.

- [ ] **Step 4: Run project-required verification if available**

Run: `bats tests/`
Expected: PASS. If BATS is unavailable in the environment, report the exact command failure and do not claim full
verification.

- [ ] **Step 5: Check git diff**

Run: `git diff -- plugins/me/skills/test/SKILL.md plugins/me/skills/review/SKILL.md plugins/me/skills/ship/SKILL.md
plugins/me/README.md docs/superpowers/plans/2026-05-12-lifecycle-skills-upstream-alignment.md`
Expected: Diff only contains the planned lifecycle skill alignment changes.

## Self-Review

- Spec coverage: The plan covers `/test`, `/review`, `/ship`, local skill cross-links, optional README alignment, and
  verification.
- Placeholder scan: No TBD/TODO/later placeholders remain.
- Type consistency: This plan edits Markdown skill files only; all referenced paths match existing project structure
  except the new plan file itself.
