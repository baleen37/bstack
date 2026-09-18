# eval-harness Skill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `me:eval-harness` skill that evaluates code changes in isolated git worktrees using capability/regression evals and model graders.

**Architecture:** Two isolated worktrees (baseline A, candidate B) created from current branch. Subagents run evals in each worktree in parallel. A judge subagent compares results and produces a structured report.

**Tech Stack:** BATS (tests), Markdown (skill), git worktrees, Agent tool (subagents)

---

## Chunk 1: Tests (write first — TDD)

### Task 1: Write failing BATS tests for eval-harness skill

**Files:**
- Create: `tests/me/eval-harness.bats`

- [ ] **Step 1: Create test file**

```bash
#!/usr/bin/env bats

load ../helpers/bats_helper

SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/eval-harness/SKILL.md"

@test "eval-harness: skill file exists" {
    [ -f "$SKILL_FILE" ]
}

@test "eval-harness: skill has valid frontmatter delimiter" {
    has_frontmatter_delimiter "$SKILL_FILE"
}

@test "eval-harness: skill has name field" {
    has_frontmatter_field "$SKILL_FILE" "name"
}

@test "eval-harness: skill has description field" {
    has_frontmatter_field "$SKILL_FILE" "description"
}

@test "eval-harness: skill name is eval-harness" {
    grep -q "^name: eval-harness$" "$SKILL_FILE"
}

@test "eval-harness: skill description starts with Use when" {
    grep -q "^description: Use when" "$SKILL_FILE"
}

@test "eval-harness: skill documents worktree isolation" {
    grep -qi "worktree" "$SKILL_FILE"
}

@test "eval-harness: skill documents parallel subagents" {
    grep -qi "parallel" "$SKILL_FILE"
}

@test "eval-harness: skill documents model grader" {
    grep -qi "model grader\|judge" "$SKILL_FILE"
}

@test "eval-harness: skill documents code grader" {
    grep -qi "code grader\|PASS/FAIL\|bats" "$SKILL_FILE"
}

@test "eval-harness: skill documents VARIANT_A and VARIANT_B input" {
    grep -q "VARIANT_A" "$SKILL_FILE"
    grep -q "VARIANT_B" "$SKILL_FILE"
}

@test "eval-harness: skill documents winner output" {
    grep -qi "winner\|Verdict\|Recommendation" "$SKILL_FILE"
}

@test "eval-harness: skill documents tie as possible outcome" {
    grep -qi "tie\|Tie" "$SKILL_FILE"
}

@test "eval-harness: skill documents anonymization" {
    grep -qi "Option 1\|Option 2\|anon" "$SKILL_FILE"
}

@test "eval-harness: skill documents cleanup" {
    grep -qi "clean up\|cleanup" "$SKILL_FILE"
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bats tests/me/eval-harness.bats
```
Expected: FAIL — "skill file exists" fails because `plugins/me/skills/eval-harness/SKILL.md` doesn't exist yet

- [ ] **Step 3: Commit failing tests**

```bash
git add tests/me/eval-harness.bats
git commit -m "test(eval-harness): add failing bats tests for eval-harness skill"
```

---

## Chunk 2: SKILL.md (make tests pass)

### Task 2: Write `plugins/me/skills/eval-harness/SKILL.md`

**Files:**
- Create: `plugins/me/skills/eval-harness/SKILL.md`

The skill covers three use cases:
1. **Baseline vs Candidate** — one worktree keeps current code, one applies a change
2. **Two implementations** — both worktrees start from HEAD and implement the same task differently
3. **Regression check** — verifies a change doesn't break existing behavior (variant A = current code)

- [ ] **Step 1: Create `plugins/me/skills/eval-harness/SKILL.md` with the following content**

The skill must contain these sections (write each directly to the file):

**Frontmatter:**
- `name: eval-harness`
- `description: Use when you need to evaluate a code change or compare two implementations — creates isolated git worktrees for each variant, runs evals (code graders + model grader), and produces a structured report`

**Sections to include:**

_When to Use_ — list these use cases: validating a refactoring doesn't break behavior, comparing two implementations, measuring whether a code change improves things. Exclude: comparing prompts (point to `me:eval`), changes that can't be tested in isolation.

_Input Format_ — document these fields:
- `TASK<<EOF...EOF` — what to evaluate
- `VARIANT_A<<EOF...EOF` — variant A description (defaults to "current code, unchanged" if omitted)
- `VARIANT_B<<EOF...EOF` — variant B description
- `Evals<<EOF...EOF` — list of eval criteria as checkboxes
- `Grader: code | model | both` — defaults to `both`

Include a guard: "If VARIANT_A and VARIANT_B are identical, stop and say: Variants are identical — nothing to compare."

_Process_ with three phases:

**Phase 0: Setup** — parse input, create two worktrees via `Agent` tool with `isolation: "worktree"` (both from current HEAD), announce start.

**Phase 1: Run Evals in Parallel** — launch two subagents in a single parallel message. Each subagent: (1) implements its variant if not "current code, unchanged", (2) runs each eval criterion and records PASS/FAIL with one-line reason, (3) if code grader: runs `bats tests/` and records results. Returns a structured report with fields: VARIANT, IMPL, EVALS, TEST_RESULTS, NOTES. Subagent B is identical structure to A with B substituted throughout.

**Phase 2: Model Grader** (if Grader is "model" or "both") — build judge prompt with task, eval criteria, and both reports anonymized (A→"Option 1", B→"Option 2", randomize presentation order). Judge scores each criterion (Option 1 wins / Option 2 wins / tie), considers correctness + code quality + test coverage, declares overall winner or tie. Launch as single judge subagent.

**Phase 3: Report** — reverse-map Option 1/2 back to A/B. Output format:

    Eval Harness Report
    ===================
    Task / Variant A / Variant B
    Code Grader Results: A: X/Y evals, Z/W tests | B: X/Y evals, Z/W tests
    Model Grader Verdict: A | B | Tie
    Reasoning: [judge explanation]
    Per-Criterion Breakdown: each criterion with winner
    Recommendation: [one sentence]

Always clean up worktrees after reporting (or note if cleanup failed).

_Key Rules:_
- Worktrees MUST be isolated — subagents must not share state
- Phase 1 subagents MUST launch in a single parallel message
- Anonymize before model grader; reverse-map before showing user
- Code grader only: skip Phase 2, report code results directly
- Model grader only: subagents describe intent without running tests

- [ ] **Step 2: Run tests — should pass now**

```bash
bats tests/me/eval-harness.bats
```
Expected: all 15 tests PASS

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/eval-harness/SKILL.md
git commit -m "feat(eval-harness): add eval-harness skill"
```

---

## Chunk 3: Update me:eval cross-reference

### Task 3: Point `me:eval` users to `me:eval-harness` for code evaluation

**Files:**
- Modify: `plugins/me/skills/eval/SKILL.md`

The current text (around line 21):
```
- Evaluating non-prompt things (code quality, design decisions, etc.)
```

- [ ] **Step 1: Update the cross-reference**

Change that line to:
```
- Evaluating non-prompt things (code quality, design decisions, etc.) — use `me:eval-harness` instead
```

- [ ] **Step 2: Run eval tests to confirm they still pass**

```bash
bats tests/me/eval.bats
```
Expected: all pass

- [ ] **Step 3: Run full test suite**

```bash
bats tests/
```
Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/eval/SKILL.md
git commit -m "docs(eval): point non-prompt eval use cases to eval-harness"
```
