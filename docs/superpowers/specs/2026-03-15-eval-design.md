# Eval Skill Design

**Date:** 2026-03-15
**Status:** Draft

## Overview

A skill for evaluating and comparing two AI prompts (A vs B) by running them as parallel subagents and using a single judge subagent to determine the winner. Designed for prompt engineering now, with a path to generalized AI response evaluation.

## Goals

- **Immediate:** Compare two prompt variants to determine which produces better AI responses
- **Long-term:** Generic framework for evaluating any two AI responses (model comparison, agent comparison, etc.)

## Architecture

### Phase 1: Parallel Response Generation

Two subagents run in parallel, each executing one prompt variant:

- `Subagent A` — runs Prompt A, returns response
- `Subagent B` — runs Prompt B, returns response

Optionally repeated N times (configurable) to gather multiple samples per variant. Multiple runs improve reliability by capturing response variance. All N×2 subagents run in parallel in a single phase.

### Phase 2: Judge Subagent

A single judge subagent receives all responses (all N runs from both A and B) in one call and selects a winner:

- Responses are **anonymized** (A → "Option 1", B → "Option 2") to prevent label bias
- **Presentation order is randomized** for each judge call to mitigate position bias
- Evaluation criteria are **auto-inferred from context** (the judge reads the prompts to understand intent, then derives appropriate criteria)
- If N > 1, consistency across runs is included as an evaluation factor; partial failures (some runs missing) are disclosed to the judge
- Returns: winner (or tie), reasoning, per-criterion breakdown
- The skill then **reverse-maps** "Option 1/Option 2" back to "A/B" before presenting output to the user

### Session Isolation

All subagents run in separate sessions. This is required to:

1. Prevent context contamination between A and B
2. Ensure the judge is not influenced by the generation process
3. Support future extension to cross-model evaluation

## Skill Input

Prompts are passed as labeled heredoc-style blocks. `PROMPT_A` and `PROMPT_B` are fixed labels. `Runs` is optional (default: 1, must be a positive integer).

```
/eval
PROMPT_A<<EOF
[multi-line content for prompt A]
EOF
PROMPT_B<<EOF
[multi-line content for prompt B]
EOF
Runs: 3
```

## Skill Output

```
Winner: A  (or B, or Tie)

Reasoning:
[Judge's explanation of why the winner was chosen]

Criteria used:
- [criterion 1]: A wins / B wins / tie
- [criterion 2]: A wins / B wins / tie
- ...

Response summaries:
- A: [brief summary of A's response(s)]
- B: [brief summary of B's response(s)]
```

## Evaluation Criteria (Auto-Inferred)

The judge subagent infers criteria from the prompt content. Examples:

| Prompt domain | Likely criteria |
|---|---|
| Code generation | Correctness, readability, edge case handling |
| Instruction writing | Clarity, completeness, actionability |
| Creative writing | Engagement, coherence, style |
| Summarization | Accuracy, conciseness, coverage |

The judge always states which criteria it used and why.

## Failure Modes

| Situation | Behavior |
|---|---|
| A subagent fails or returns empty | Skip that run; disclose the missing run count to the judge; if all runs for one side fail, declare the other the winner by default and note the failure |
| Judge cannot infer criteria | Judge falls back to general criteria: clarity, usefulness, accuracy |
| Prompts A and B are identical | Skill detects this before running and returns an error: "Prompts are identical — nothing to compare" |
| All runs result in a tie | Output `Winner: Tie` with explanation |

## Key Design Decisions

### Why a single judge with multiple samples?

LLM judges have variance. Running A/B prompts N times gives the judge more signal — multiple samples per variant reduce the effect of any single outlier response. A single consolidated judge call (rather than one call per run) also avoids aggregation ambiguity.

### Why anonymize A/B labels?

LLMs exhibit position bias (preferring whichever option is presented first) and label bias (preferring "A" or "Option A"). Anonymizing to "Option 1/Option 2" with randomized presentation order mitigates both.

### Why session isolation?

A judge that observed the generation process may be anchored to it. Isolation ensures the judge evaluates outputs on merit, not process. It also makes the architecture extensible to multi-model evaluation where session boundaries map to model boundaries.

Session isolation is achieved by using the `Agent` tool for all subagents — each `Agent` call runs in its own context window with no shared state.

## Future Extensions

1. **Model comparison** — run Prompt A on Model X and Model Y instead of two different prompts
2. **Multi-candidate eval** — extend to A/B/C with a tournament bracket
3. **Ensemble judge** — run multiple judge subagents and take majority vote for higher confidence
4. **Evaluation history** — store results for tracking prompt improvement over time

## Implementation Notes

- Skill lives in `plugins/me/skills/eval/SKILL.md`
- Uses the `Agent` tool (subagent_type: general-purpose) for all subagents
- Phase 1 subagents run concurrently in a single message (parallel tool calls)
- Phase 2 judge runs after Phase 1 completes
- N runs default to 1; values of 3 or 5 recommended for important decisions
