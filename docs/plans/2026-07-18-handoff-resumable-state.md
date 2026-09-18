# Handoff Resumable State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reshape `me:handoff` so every handoff clearly separates completed work, current state, and verified next actions without duplicating resume guidance.

**Architecture:** Keep the skill write-only and preserve its XDG output location. Replace the overlapping output sections with a small required core plus conditional context, and enforce the contract with a focused Bats structure test.

**Tech Stack:** Markdown skill instructions, Bash, Bats

## Global Constraints

- Preserve `${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff` as the output directory.
- Preserve explicit-user-only invocation and write-only behavior.
- Do not restore `pickup` or add automatic resume logic.
- Do not overwrite or discard the existing uncommitted README, setup, pickup-removal, or handoff changes.
- Keep the skill concise and omit empty conditional sections.

---

### Task 1: Replace overlapping handoff sections with a resumable state contract

**Files:**
- Create: `tests/me/handoff-skill.bats`
- Modify: `plugins/me/skills/handoff/SKILL.md`

**Interfaces:**
- Consumes: the existing write-only `/handoff` workflow and XDG path contract
- Produces: required `Task`, `Completed`, `Current State`, and `Next Steps` sections; conditional `Blockers & Open Questions`, `Context`, `Design Decisions`, `Failed Approaches`, and `Gotchas`

- [ ] **Step 1: Write the failing structure test**

```bash
#!/usr/bin/env bats

load ../helpers/bats_helper

setup() {
    SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/handoff/SKILL.md"
}

@test "me: handoff separates completed current and next state" {
    grep -q '^## Task$' "$SKILL_FILE"
    grep -q '^## Completed$' "$SKILL_FILE"
    grep -q '^## Current State$' "$SKILL_FILE"
    grep -q '^## Next Steps$' "$SKILL_FILE"
}

@test "me: handoff has one resume protocol without overlapping sections" {
    grep -q '^## Resume Protocol$' "$SKILL_FILE"
    run grep -q '^## Resume Prompt$' "$SKILL_FILE"
    assert_failure
    run grep -q '^## Resume Checkpoint$' "$SKILL_FILE"
    assert_failure
}

@test "me: handoff preserves XDG write-only boundaries" {
    grep -Fq '${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff' "$SKILL_FILE"
    grep -q 'write-only' "$SKILL_FILE"
    grep -q 'Does not start a new session or read prior handoffs' "$SKILL_FILE"
}

@test "me: handoff distinguishes temporary context from permanent rules" {
    grep -q 'AGENTS.md' "$SKILL_FILE"
    grep -q 'CLAUDE.md' "$SKILL_FILE"
    grep -q 'First action' "$SKILL_FILE"
    grep -q 'Last verified' "$SKILL_FILE"
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `bats tests/me/handoff-skill.bats`

Expected: FAIL because `## Completed`, `## Task`, and `## Resume Protocol` do not exist and the two overlapping resume sections still exist.

- [ ] **Step 3: Implement the minimal skill rewrite**

Update `plugins/me/skills/handoff/SKILL.md` so:

- `What /handoff does` extracts task, completed work, current state, next steps, blockers, and stable context pointers.
- The output template contains the required core from the design spec.
- `Next Steps` begins with `First action` and pairs important actions with verification or `Done when` evidence.
- `Resume Protocol` requires worktree/branch/commit comparison, re-running `Last verified`, reporting mismatches, and only then starting `First action`.
- Conditional sections are emitted only when they prevent a concrete resume error.
- Persistent rules point to `AGENTS.md` or `CLAUDE.md` instead of being copied into each handoff.
- Existing XDG path, continuation metadata, pre-write snapshot, validation, and secret handling remain intact.

- [ ] **Step 4: Run focused and structural tests and verify GREEN**

Run: `bats tests/me/handoff-skill.bats tests/frontmatter_tests.bats tests/me/me-specific.bats`

Expected: all tests pass with zero failures.

- [ ] **Step 5: Run a behavior evaluation**

Use the same auth-timeout scenario from the baseline evaluation. Verify that completed work, current work, first action, preflight verification, and failed approach each appear once in the correct section.

- [ ] **Step 6: Commit the implementation**

```bash
git add tests/me/handoff-skill.bats plugins/me/skills/handoff/SKILL.md docs/superpowers/plans/2026-07-18-handoff-resumable-state.md
git commit -m "feat(handoff): clarify resumable task state"
```
