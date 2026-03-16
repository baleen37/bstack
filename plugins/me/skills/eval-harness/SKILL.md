---
name: eval-harness
description: Use when you need to compare two code implementations against defined criteria — validating a refactoring doesn't break behavior, comparing two approaches, or measuring whether a code change improves things. Do NOT use for prompt comparison (use me:eval instead), or for changes that cannot be tested in isolation.
---

# eval-harness

A structured harness for comparing two code variants using worktree isolation, parallel subagent execution, and optional model grader judgment.

## When to Use

Use when:
- Validating a refactoring doesn't break behavior
- Comparing two implementations side-by-side
- Measuring whether a code change improves things

Do NOT use when:
- Comparing prompts (use `me:eval` instead)
- Changes cannot be tested in isolation

## Input Format

Provide the following fields:

| Field | Description | Default |
|-------|-------------|---------|
| TASK | What is being compared | (required) |
| VARIANT_A | First implementation | `current code, unchanged` |
| VARIANT_B | Second implementation | (required) |
| Evals | Checklist of criteria to evaluate | (required) |
| Grader | `code`, `model`, or `both` | `both` |

**Guard**: If VARIANT_A and VARIANT_B are identical, stop and report — do not proceed.

## Process

### Phase 0: Setup

1. Parse all input fields.
2. Create two worktrees via Agent tool with `isolation: "worktree"`, both branched from current HEAD.
   - One worktree for VARIANT_A
   - One worktree for VARIANT_B

### Phase 1: Parallel Evaluation

Launch two subagents in a **single parallel message**. Each subagent independently:

1. Implements its variant (skip if variant is `current code, unchanged`)
2. Runs each eval criterion, recording PASS/FAIL with reason
3. Runs `bats tests/` if code grader is enabled
4. Returns a report with:
   - `VARIANT`: A or B
   - `IMPL`: summary of changes made
   - `EVALS`: per-criterion PASS/FAIL results
   - `TEST_RESULTS`: output of bats run (if applicable)
   - `NOTES`: any anomalies or observations

### Phase 2: Model Grader (when grader is `model` or `both`)

Construct a judge prompt that includes:
- The original task and eval criteria
- Both subagent reports **anonymized**: VARIANT_A → "Option 1", VARIANT_B → "Option 2"
- Randomize the order presented to avoid position bias

Send to a single judge subagent. The judge:
- Scores each criterion per option
- Declares a **winner** or **tie** with reasoning
- Returns a **Verdict**

### Phase 3: Reverse-Map and Report

1. Reverse-map "Option 1"/"Option 2" back to VARIANT_A/VARIANT_B.
2. Output final report:

```
## Eval-Harness Report

**Task**: <task>
**Variant A**: <description>
**Variant B**: <description>

### Code Grader Results
<PASS/FAIL per criterion, bats output if run>

### Model Grader Verdict
Winner: <Variant A | Variant B | Tie>

### Reasoning
<Judge's reasoning>

### Per-Criterion Breakdown
| Criterion | Variant A | Variant B |
|-----------|-----------|-----------|
| ...       | PASS/FAIL | PASS/FAIL |

### Recommendation
<Which variant to adopt and why>
```

3. **Clean up** all worktrees after reporting is complete.

## Key Rules

- Worktrees must remain isolated throughout evaluation
- Phase 1 subagents MUST run in parallel (single message)
- Always anonymize before sending to the judge; always reverse-map before showing the user
- A tie is a valid outcome — do not force a winner
- Cleanup of worktrees is mandatory, even on failure
