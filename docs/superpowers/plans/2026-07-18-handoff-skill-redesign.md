# Handoff Skill Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `me:handoff` produce a compact, verifiable task-state transfer centered on completed work, current state, and exact next actions.

**Architecture:** Keep the skill self-contained in one `SKILL.md`. Replace overlapping output sections with six core slots and a small conditional appendix, then lock the document contract with Bats tests and fresh-agent behavioral scenarios.

**Tech Stack:** Markdown skill instructions, Bash, Bats

## Global Constraints

- Preserve all pre-existing uncommitted changes outside files explicitly listed in a task.
- Do not reintroduce `pickup` or add resume/read logic.
- Do not change the in-progress XDG handoff storage migration.
- Do not copy full conversations, command logs, or permanent repository rules into handoffs.
- Use RED-GREEN-REFACTOR: observe baseline failures before modifying `SKILL.md`.

---

## File Structure

- `plugins/me/skills/handoff/SKILL.md`: the complete handoff writing workflow and output contract.
- `tests/me/handoff-skill.bats`: structural regression tests for the required output slots, resume contract, and removed redundant headings.

### Task 1: Lock the Task-State Output Contract

**Files:**
- Create: `tests/me/handoff-skill.bats`
- Modify: `plugins/me/skills/handoff/SKILL.md`

**Interfaces:**
- Consumes: current session facts, git/environment snapshot, and optional text supplied with `/handoff`.
- Produces: one Markdown handoff containing `Task`, `Completed`, `Current State`, `Next Steps`, optional `Blockers & Open Questions`, `Pointers`, and only relevant conditional context.

- [ ] **Step 1: Run three fresh-agent baseline scenarios without the redesigned skill**

Give fresh agents the current `plugins/me/skills/handoff/SKILL.md` and one scenario each. Ask for only the generated handoff Markdown.

Scenario A:

```text
Create a handoff from these facts: goal is to add OAuth refresh; parsing and unit tests are complete; integration wiring is in progress; worktree has unrelated user-owned notes.md; unit tests passed with `bun test auth`; next action is wiring refresh into middleware; done when the integration test passes. Do not invent facts.
```

Scenario B:

```text
Create a handoff from these facts: PR #42 is merged according to the conversation but has not been rechecked; deployment has not started; the user said at handoff time, "verify the merge, then deploy beta"; record the safest exact first action. Do not invent commands that were not provided.
```

Scenario C:

```text
Create a handoff from these facts: attempted `npm test` failed because this repository uses Bun; `AGENTS.md` already says to use Bun; the remaining work is to run `bun test` and fix only failures caused by the current patch. Keep permanent rules out of the handoff body unless a pointer is needed.
```

Record whether each output:

- separates completed, current, and remaining work;
- has exactly one explicit first action;
- distinguishes unverified claims from verified state;
- preserves user-owned dirty state;
- references `AGENTS.md` instead of copying its permanent rule;
- avoids overlapping resume/checkpoint/change-summary sections.

Expected RED evidence: at least one scenario buries completed work under current state or emits overlapping `Resume Prompt`, `Recent Changes`, and `Resume Checkpoint` content.

- [ ] **Step 2: Add the failing structural regression test**

Create `tests/me/handoff-skill.bats` with:

```bash
#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load ../helpers/bats_helper

@test "me: handoff skill defines the task-state output contract" {
    local skill="${PROJECT_ROOT}/plugins/me/skills/handoff/SKILL.md"

    grep -q '^## Task$' "$skill"
    grep -q '^## Completed$' "$skill"
    grep -q '^## Current State$' "$skill"
    grep -q '^## Next Steps$' "$skill"
    grep -q '^## Blockers & Open Questions$' "$skill"
    grep -q '^## Pointers$' "$skill"
}

@test "me: handoff skill requires a verifiable first action" {
    local skill="${PROJECT_ROOT}/plugins/me/skills/handoff/SKILL.md"

    grep -q 'First action:' "$skill"
    grep -q 'Last verified:' "$skill"
    grep -q 'Confirm the recorded worktree, branch, and commit' "$skill"
    grep -q 'Report material drift or mismatch' "$skill"
}

@test "me: handoff skill removes overlapping legacy sections" {
    local skill="${PROJECT_ROOT}/plugins/me/skills/handoff/SKILL.md"

    run grep -q '^## Goal & Current State$' "$skill"
    assert_failure

    run grep -q '^## Recent Changes$' "$skill"
    assert_failure

    run grep -q '^## Resume Checkpoint$' "$skill"
    assert_failure

    run grep -q '^## User Preferences$' "$skill"
    assert_failure
}
```

- [ ] **Step 3: Run the new test and verify RED**

Run:

```bash
bats tests/me/handoff-skill.bats
```

Expected: FAIL because the current skill does not contain the new `Task`, `Completed`, `Pointers`, or resume-contract wording.

- [ ] **Step 4: Rewrite the skill around the approved output contract**

Keep the existing frontmatter and XDG storage rules. Replace the overlapping template and content rules with this exact structure:

```markdown
# Handoff: <one-line title>

## Task
- Goal: <goal derived from the session>
- Scope: <in-scope work and explicit boundaries>
- Done when: <verifiable completion condition>

## Completed
- <concrete completed outcome>

## Current State
- In progress: <unfinished work currently underway>
- Workspace health: clean / dirty, including user-owned unrelated changes
- Last verified: `<command-or-check>` → <result>

## Next Steps
1. First action: confirm the recorded worktree, branch, and commit, then run `<re-check>`.
2. <next action> → verify with `<check>`.

## Blockers & Open Questions
- <unresolved decision, dependency, or unknown>

## Pointers
- Files: `path/a.ts`
- PR / issue / doc / run: <stable identifier or URL>

## Design Decisions
- Decision: <chosen approach> — Reason: <why it was chosen>

## Failed Approaches
- Tried: `<command-or-approach>` — Failed because: <exact useful reason>

## Gotchas
- <forward-looking constraint the next session must preserve>
```

State that `Task` and `Current State` are always present; omit every other empty section. Add a receiving-session contract with these exact requirements:

1. Confirm the recorded worktree, branch, and commit still match.
2. Run the recorded re-check before trusting state claims.
3. Report material drift or mismatch instead of inferring through it.
4. Start with the recorded `First action`.

Keep the existing rule that explicit text passed with `/handoff` is placed first in `Next Steps`. Replace copied `User Preferences` with a pointer to an existing persistent instruction file when relevant; do not modify that instruction file during handoff. Keep validation for placeholders, secrets, referenced paths, and state claims.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run:

```bash
bats tests/me/handoff-skill.bats
bats tests/frontmatter_tests.bats
```

Expected: both commands PASS.

- [ ] **Step 6: Re-run the three fresh-agent scenarios with the redesigned skill**

Use the same prompts from Step 1 and only replace the supplied skill body with the revised file. Expected for all three:

- completed/current/next state is visibly separated;
- one first action is unambiguous;
- unverified merge/deploy claims are softened and paired with a re-check;
- user-owned dirty state remains visible;
- permanent Bun guidance is referenced through `AGENTS.md` rather than duplicated;
- no empty or redundant legacy sections appear.

If a scenario fails, make the smallest wording correction that addresses the observed failure and repeat only the failing scenario plus the focused Bats tests.

- [ ] **Step 7: Run repository verification**

Run:

```bash
npm test
git diff --check
```

Expected: all repository tests pass and `git diff --check` emits no output.

- [ ] **Step 8: Commit only the skill and its regression test**

Run:

```bash
git add plugins/me/skills/handoff/SKILL.md tests/me/handoff-skill.bats
git diff --cached --check
git diff --cached --name-only
git commit -m "feat(handoff): focus handoffs on resumable task state"
```

Expected staged paths:

```text
plugins/me/skills/handoff/SKILL.md
tests/me/handoff-skill.bats
```
