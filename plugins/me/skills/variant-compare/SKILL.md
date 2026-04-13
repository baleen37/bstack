---
name: variant-compare
description: Use when comparing two variants (code, LLM prompts, CLI commands, or any executable) against defined criteria with the same inputs. Do NOT use when variants cannot produce observable, comparable output.
---

# eval-harness

A structured harness for comparing two variants using parallel subagent execution and model grader judgment. Works for any comparison where both sides produce observable output.

## When to Use

- Comparing two code implementations
- Comparing two LLM prompts or model configs
- Comparing CLI commands, API calls, or any executable
- Any "same input → two approaches → compare output" scenario

## Variant Types

| Type | How it runs | Example |
|------|-------------|---------|
| `code` | Implement in isolated worktree, run tests | Refactoring, algorithm swap |
| `llm` | Call LLM with given config against all INPUTS | Prompt A vs prompt B |
| `command` | Run shell command against all INPUTS, capture stdout/stderr | CLI flag comparison |
| `custom` | Freeform — subagent follows instructions literally | API call, config swap |

## Input Format

| Field | Description | Default |
|-------|-------------|---------|
| TASK | What is being compared | (required) |
| VARIANT_A | `type:` + config/instructions | `type: code, current code unchanged` |
| VARIANT_B | `type:` + config/instructions | (required) |
| INPUTS | Shared test inputs passed to both variants | (optional, but required for `llm`/`command`) |
| Evals | Checklist of judgment criteria | (required) |
| Grader | `auto` or `none` | `auto` |

**Grader `auto`**: model grader always runs. Also runs `bats tests/` if either variant is `code`.

**Worktree rule**: Create worktrees only for variants of type `code`. A `code` variant always runs in its own worktree; non-`code` variants do not.

**Guard**: If VARIANT_A and VARIANT_B are textually identical, stop — do not proceed.

## Process

### Phase 0: Setup

1. Parse all fields and identify variant types.
2. For each variant of type `code`: create a worktree via Agent tool with `isolation: "worktree"`.
3. Non-`code` variants need no worktree.

### Phase 1: Parallel Collection (output only — no scoring)

Launch two subagents in a **single parallel message**. Each subagent:

1. Executes its variant:
   - `code`: implement changes in worktree, run `bats tests/`, capture full output
   - `llm`: call the model with the prompt config against each input, collect all responses
   - `command`: run the command against each input, capture stdout/stderr
   - `custom`: follow freeform instructions, capture all observable output
2. **Does NOT score or judge** — raw collection only
3. Returns:
   - `VARIANT`: A or B
   - `TYPE`: variant type
   - `EXEC_SUMMARY`: what was run
   - `OUTPUTS`: raw outputs per input (responses, stdout, test results)
   - `NOTES`: errors, anomalies, or partial failures

**On failure**: if a variant cannot execute, record the error in NOTES and return what was collected. Do not fabricate output.

### Phase 2: Model Grader (when grader is `auto`)

1. Anonymize before constructing the judge prompt:
   - Count the second digit of the current minute (e.g. minute=47 → digit=7). If odd: A→Option 1, B→Option 2. If even: B→Option 1, A→Option 2.
2. Judge prompt includes: TASK, INPUTS, Evals, both subagent raw outputs (anonymized)
3. Judge evaluates each Eval criterion per option and returns:
   - Per-criterion verdict: WIN / LOSE / TIE (with reasoning)
   - Note if both options fail a criterion — do not force a winner for that criterion
   - Overall winner or TIE

### Phase 3: Reverse-Map and Report

1. Reverse-map Option 1/2 back to VARIANT_A/B.
2. Clean up all worktrees before outputting the report.
3. Output:

```
## Eval-Harness Report

**Task**: <task>
**Variant A**: <type + description>
**Variant B**: <type + description>

### Execution Summary
<EXEC_SUMMARY per variant; errors if any>

### Per-Criterion Breakdown
| Criterion | Variant A | Variant B |
|-----------|-----------|-----------|
| ...       | WIN/LOSE/TIE | WIN/LOSE/TIE |

### Model Grader Verdict
Winner: <Variant A | Variant B | Tie>

### Reasoning
<Judge's reasoning>

### Recommendation
<Which variant to adopt and why; if a variant failed to execute, say so explicitly>
```

If grader is `none`: omit Model Grader Verdict and Reasoning sections; include only Execution Summary and raw outputs.

## Key Rules

- Phase 1 subagents MUST run in parallel (single message)
- Phase 1 collects output only — all scoring happens in Phase 2
- Always anonymize before judge; always reverse-map before showing the user
- A tie is a valid outcome — do not force a winner
- Worktree cleanup happens before the report, not after
- Never fabricate output — execution failure is a valid result
