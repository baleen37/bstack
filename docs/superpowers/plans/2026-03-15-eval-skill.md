# Eval Skill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an `eval` skill that compares two AI prompts (A vs B) by running them as parallel subagents and using a judge subagent to declare a winner.

**Architecture:** Phase 1 spawns two parallel general-purpose subagents (one per prompt), optionally N times. Phase 2 spawns a single judge subagent that receives all anonymized responses in one call, infers evaluation criteria from context, and returns a winner with reasoning. All subagents run in isolated sessions via the `Agent` tool.

**Tech Stack:** Markdown (SKILL.md), BATS (tests), existing `Agent` tool pattern from Claude Code.

---

## Chunk 1: Skill file

### Task 1: Write the failing BATS test for skill structure

**Files:**
- Create: `tests/me/eval.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats

load ../helpers/bats_helper

SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/eval/SKILL.md"

@test "eval: skill file exists" {
    [ -f "$SKILL_FILE" ]
}

@test "eval: skill has valid frontmatter delimiter" {
    has_frontmatter_delimiter "$SKILL_FILE"
}

@test "eval: skill has name field" {
    has_frontmatter_field "$SKILL_FILE" "name"
}

@test "eval: skill has description field" {
    has_frontmatter_field "$SKILL_FILE" "description"
}

@test "eval: skill name is eval" {
    grep -q "^name: eval$" "$SKILL_FILE"
}

@test "eval: skill description starts with Use when" {
    grep -q "^description: Use when" "$SKILL_FILE"
}

@test "eval: skill documents Phase 1 parallel subagents" {
    grep -qi "phase 1\|parallel" "$SKILL_FILE"
}

@test "eval: skill documents judge subagent" {
    grep -qi "judge" "$SKILL_FILE"
}

@test "eval: skill documents anonymization" {
    grep -qi "anon\|Option 1\|Option 2" "$SKILL_FILE"
}

@test "eval: skill documents PROMPT_A and PROMPT_B input format" {
    grep -q "PROMPT_A" "$SKILL_FILE"
    grep -q "PROMPT_B" "$SKILL_FILE"
}

@test "eval: skill documents winner output" {
    grep -qi "winner" "$SKILL_FILE"
}

@test "eval: skill documents tie as possible outcome" {
    grep -qi "tie\|Tie" "$SKILL_FILE"
}
```

- [ ] **Step 2: Run tests to confirm they all fail**

```bash
bats tests/me/eval.bats
```

Expected: All 12 tests FAIL with "No such file or directory" or similar.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/me/eval.bats
git commit -m "test(eval): add failing BATS tests for eval skill structure"
```

---

### Task 2: Write the SKILL.md

**Files:**
- Create: `plugins/me/skills/eval/SKILL.md`

- [ ] **Step 1: Create the skill directory and file**

```bash
mkdir -p plugins/me/skills/eval
```

Create `plugins/me/skills/eval/SKILL.md` with the following content:

```markdown
---
name: eval
description: Use when comparing two prompt variants (A vs B) to determine which produces better AI responses — runs both as parallel subagents, then uses a judge subagent to pick the winner
---

# Eval

Compare two prompts by running them as isolated subagents, then judging the results.

## When to Use

Use this skill when you want to determine which of two prompt variants produces better AI responses. Common cases:

- Refining a prompt and wanting to know if the new version is actually better
- Comparing two different phrasings of the same instruction
- Validating a prompt change before committing to it

Do NOT use this for:
- Comparing more than two prompts at once (run multiple evals instead)
- Evaluating non-prompt things (code quality, design decisions, etc.)

## Input Format

```
/eval
PROMPT_A<<EOF
[your first prompt — can be multi-line]
EOF
PROMPT_B<<EOF
[your second prompt — can be multi-line]
EOF
Runs: 3
```

`Runs` is optional (default: 1). Use 3 or 5 for important decisions. Must be a positive integer.

**Guard:** If PROMPT_A and PROMPT_B are identical (string equality), stop immediately and say: "Prompts are identical — nothing to compare."

## Process

### Phase 1: Generate Responses

Parse PROMPT_A and PROMPT_B from the input. Validate they are not identical.

Launch **2×Runs subagents in parallel** in a single message — all at once, not sequentially:
- For each run: one `Agent` (general-purpose) for Prompt A, one `Agent` (general-purpose) for Prompt B
- Each subagent's prompt is exactly the prompt text provided (nothing added)
- Collect all responses; note any failures (subagent error or empty response)

If all runs for one side fail, declare the other the winner immediately and note the failure. If a run partially fails (some succeed, some fail), disclose the missing run count to the judge.

### Phase 2: Judge

Build a single judge prompt:

1. **Anonymize:** Present Prompt A as "Option 1" and Prompt B as "Option 2". Randomize which is listed first in the prompt.
2. **Include all responses:** Show each run's response grouped by option (e.g., "Option 1 – Run 1", "Option 1 – Run 2").
3. **Infer criteria:** Instruct the judge to read both prompts, understand their intent and domain, and derive the most relevant evaluation criteria before scoring.
4. **Ask for:** Winner (Option 1, Option 2, or Tie), reasoning, and a per-criterion breakdown (each criterion: Option 1 wins / Option 2 wins / tie).
5. If Runs > 1, instruct the judge to also evaluate consistency across runs as a factor.
6. If any runs are missing due to failure, disclose this in the judge prompt.

Launch the judge as a single `Agent` (general-purpose) subagent.

### Output

After receiving the judge's response, reverse-map "Option 1/Option 2" back to "A/B" and present:

```
Winner: A  (or B, or Tie)

Reasoning:
[Judge's explanation]

Criteria used:
- [criterion]: A wins / B wins / tie
- ...

Response summaries:
- A: [brief summary]
- B: [brief summary]
```

## Key Rules

- All subagents run via the `Agent` tool — each call is an isolated session with no shared context.
- Phase 1 subagents MUST be launched in a single parallel message (not one by one).
- The judge receives ONE consolidated call with all responses.
- Never show the judge which option is A or B until after its verdict.
- Always reverse-map before showing the user.
```

- [ ] **Step 2: Run tests to confirm they now pass**

```bash
bats tests/me/eval.bats
```

Expected: All 12 tests PASS.

- [ ] **Step 3: Run full test suite to catch regressions**

```bash
bats tests/
```

Expected: All tests pass (same count as before this task).

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/eval/SKILL.md
git commit -m "feat(eval): add eval skill for A/B prompt comparison"
```

---

## Chunk 2: Integration into test suite

### Task 3: Verify eval tests are picked up by the full test run

**Files:**
- Read: `tests/me/me-specific.bats` (to understand existing eval-adjacent test patterns — no changes needed)

- [ ] **Step 1: Run just the eval tests in isolation**

```bash
bats tests/me/eval.bats -v
```

Expected: 12 tests, all PASS. Output shows each test name.

- [ ] **Step 2: Run the full me/ suite**

```bash
bats tests/me/
```

Expected: All tests pass including the new eval tests.

- [ ] **Step 3: Run the complete test suite**

```bash
bats tests/
```

Expected: All tests pass, no regressions.

- [ ] **Step 4: Run pre-commit hooks**

```bash
pre-commit run --all-files
```

Expected: All hooks pass (shellcheck, markdownlint, etc.).

If markdownlint fails on `SKILL.md`:
- Check the error message for the rule (e.g., MD040 for fenced code blocks without language)
- Fix the specific line in SKILL.md
- Re-run `pre-commit run --all-files` until clean

- [ ] **Step 5: Commit if any fixes were needed**

Only commit if step 4 required changes:

```bash
git add plugins/me/skills/eval/SKILL.md
git commit -m "fix(eval): fix markdownlint issues in eval skill"
```

If no fixes needed, skip this step.
