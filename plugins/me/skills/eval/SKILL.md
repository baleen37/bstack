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
- Evaluating non-prompt things (code quality, design decisions, etc.) — use `me:eval-harness` instead

## Input Format

```text
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

**Guard:** If PROMPT_A and PROMPT_B are identical (string equality), stop immediately and say:
"Prompts are identical — nothing to compare."

## Process

### Phase 1: Generate Responses

Parse PROMPT_A and PROMPT_B from the input. Validate they are not identical.

Launch all subagents **in parallel in a single message** — for each of the N runs, that means one
`Agent` (general-purpose) for Prompt A and one for Prompt B (total: 2×N calls, all at once):

- For each run: one `Agent` (general-purpose) for Prompt A, one `Agent` (general-purpose) for Prompt B
- Each subagent's prompt is exactly the prompt text provided (nothing added)
- Collect all responses; note any failures (subagent error or empty response)

If all runs for one side fail, declare the other the winner immediately and note the failure.
If a run partially fails (some succeed, some fail), disclose the missing run count to the judge.

### Phase 2: Judge

Build a single judge prompt:

1. **Anonymize:** Assign Prompt A → "Option 1" and Prompt B → "Option 2" (fixed mapping — do not
   change). Randomize which option is presented *first* in the judge prompt, but keep the labels
   "Option 1" and "Option 2" as assigned. This way reverse-mapping is always: Option 1 = A, Option 2 = B.
2. **Include all responses:** Show each run's response grouped by option
   (e.g., "Option 1 – Run 1", "Option 1 – Run 2").
3. **Infer criteria:** Instruct the judge to read both prompts, understand their intent and domain,
   and derive the most relevant evaluation criteria before scoring.
4. **Ask for:** Winner (Option 1, Option 2, or Tie), reasoning, and a per-criterion breakdown
   (each criterion: Option 1 wins / Option 2 wins / tie).
5. If Runs > 1, instruct the judge to also evaluate consistency across runs as a factor.
6. If any runs are missing due to failure, disclose this in the judge prompt.

Launch the judge as a single `Agent` (general-purpose) subagent.

### Output

After receiving the judge's response, reverse-map "Option 1/Option 2" back to "A/B" and present:

```text
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
- Never show the judge which option is A or B until after its verdict. (The prompt *contents* may be shared with the judge — what must stay hidden is the A/B label mapping, i.e. which letter corresponds to which option number.)
- Always reverse-map before showing the user.
