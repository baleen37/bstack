# Adopt Matt Pocock Engineering Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the requested Matt Pocock engineering skills to the `me` plugin as an exact upstream snapshot.

**Architecture:** Copy the pinned upstream skill files and transitive support files into `plugins/me/skills/`, replace the existing `research` and `handoff` documents with their upstream counterparts, update the user-facing inventory, and regenerate Codex artifacts.

**Tech Stack:** Markdown skill files, Bash synchronization scripts, BATS structural tests, SHA-256 verification.

## Global Constraints

- Upstream source commit: `84fdeffd12f2ee307994d1eb6feb48173b6e0502`.
- Do not adapt upstream skill content to bstack, Jira, Notion, Claude, or Codex conventions.
- Replace only `plugins/me/skills/research/SKILL.md` and `plugins/me/skills/handoff/SKILL.md`; preserve the research evaluator/scripts.
- Do not create runtime project documents such as `CONTEXT.md`, ADRs, or issue-tracker configuration during installation.
- Do not edit generated Codex files directly; run `bun run sync:codex`.

---

### Task 1: Establish the source manifest and baseline

**Files:**
- Create: `docs/superpowers/specs/2026-08-07-adopt-matt-pocock-engineering-skills-design.md` (approved)
- Create: `docs/superpowers/plans/2026-08-07-adopt-matt-pocock-engineering-skills.md`
- Test: repository status, source commit, and baseline structural suite

**Interfaces:**
- Consumes: `/tmp/matt-pocock-skills.kk9H4Z` at commit `84fdeffd12f2ee307994d1eb6feb48173b6e0502`.
- Produces: a fixed source manifest and a baseline result for later comparison.

- [x] **Step 1: Verify the linked worktree and current diff**

Run `git status --short --branch` and `git diff --check`.

Expected: the worktree is `feat/addd`; only the approved design document is untracked; no whitespace errors.

- [x] **Step 2: Verify the upstream snapshot**

Run `git -C /tmp/matt-pocock-skills.kk9H4Z rev-parse HEAD`.

Expected: `84fdeffd12f2ee307994d1eb6feb48173b6e0502`.

- [x] **Step 3: Run the baseline structural tests**

Run `bash tests/run-all-tests.sh`.

Expected: the existing suite passes before skill files are copied. Result: all baseline tests passed.

### Task 2: Copy the exact upstream skill bundle

**Files:**
- Create: `plugins/me/skills/grilling/`
- Create: `plugins/me/skills/domain-modeling/`
- Create: `plugins/me/skills/grill-with-docs/SKILL.md`
- Create: `plugins/me/skills/code-review/SKILL.md`
- Create: `plugins/me/skills/to-tickets/SKILL.md`
- Create: `plugins/me/skills/research/agents/openai.yaml`
- Modify: `plugins/me/skills/research/SKILL.md`
- Create: `plugins/me/skills/handoff/agents/openai.yaml`
- Modify: `plugins/me/skills/handoff/SKILL.md`
- Delete: `tests/me/handoff-skill.bats`
- Delete: `tests/fixtures/handoff/compound-user-direction.md`

**Interfaces:**
- Consumes: the pinned upstream skill directories.
- Produces: exact upstream skill files in the `me` plugin namespace.

- [x] **Step 1: Copy the upstream files without rewriting them**

Copy the upstream `grilling`, `domain-modeling`, `grill-with-docs`, `code-review`, `to-tickets`, `research`, and `handoff` files into their matching `plugins/me/skills/` directories.

Expected: all requested skills and their transitive support files exist; only the existing `research/SKILL.md` and `handoff/SKILL.md` documents are replaced, and obsolete tests for the previous handoff contract are removed. Result: copied.

- [x] **Step 2: Verify exact file contents**

Run a SHA-256 comparison for every copied or replaced file against the corresponding upstream file.

Expected: every pair has the same digest; no upstream skill content was adapted. Result: all 19 source/target pairs matched.

### Task 3: Expose the skills and regenerate artifacts

**Files:**
- Modify: `plugins/me/README.md`
- Modify: generated Codex marketplace/plugin manifests through `bun run sync:codex`

**Interfaces:**
- Consumes: the copied skill directories.
- Produces: a user-visible inventory and synchronized Codex artifacts.

- [x] **Step 1: Add the new skill names to the README inventory**

Add `grill-with-docs`, `domain-modeling`, `grilling`, `code-review`, `to-tickets`, and the upstream `research` and `handoff` descriptions to `plugins/me/README.md`.

Expected: every newly available skill is listed once. Result: README updated.

- [x] **Step 2: Regenerate Codex artifacts**

Run `bun run sync:codex`.

Expected: generated Codex files reflect the new skills with no manual edits. Result: synchronized.

- [x] **Step 3: Check generated artifacts**

Run `bun run check:codex`.

Expected: exit code 0. Result: passed.

### Task 4: Run final verification

**Files:**
- Test: `tests/run-all-tests.sh`, plugin-loading tests, and the final diff

**Interfaces:**
- Consumes: the completed skill bundle and generated artifacts.
- Produces: evidence that the plugin loads and the upstream content remains exact.

- [x] **Step 1: Run focused plugin tests**

Run `bats tests/integration/plugin_loading.bats tests/integration/cross_plugin_interactions.bats`.

Expected: all focused tests pass. Result: 18 tests passed.

- [x] **Step 2: Run the full suite**

Run `bash tests/run-all-tests.sh`.

Expected: all tests pass with no new failures. Result: all tests passed.

- [x] **Step 3: Check the final diff**

Run `git diff --check`, `git status --short`, and `git diff --stat`.

Expected: only the approved design/plan, upstream skill bundle, README, generated artifacts, and obsolete handoff contract test/fixture are changed. Result: verified; 19 upstream file pairs matched exactly.
