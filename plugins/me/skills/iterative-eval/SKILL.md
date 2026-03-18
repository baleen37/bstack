---
name: iterative-eval
description: Use when improving a file (prompt, config, template) toward reference quality through repeated single-change A/B testing. Do NOT use for one-off comparisons (use eval-harness instead).
---

# iterative-eval

Improve a file toward reference quality by making one small change at a time, testing each against reference examples, and adopting only what works.

## When to Use

- Tuning an LLM prompt toward gold-standard example outputs
- Iteratively improving a config, template, or any text file against reference quality
- Any "improve X to be more like Y" task where progress is incremental

## When NOT to Use

- One-off A/B comparison → use `eval-harness`
- Code refactoring with tests → use `eval-harness` with `type: code`
- No reference exists to compare against

## Core Principle: One Change at a Time

Each iteration makes exactly ONE small, testable change. Never bundle multiple changes.

Why: bundled changes make it impossible to know what helped and what hurt. A change that helps on emotion topics might hurt on comedy topics — you'll never know if you changed both the emotion rule and the comedy rule at once.

## Input Format

| Field | Description | Required |
|-------|-------------|----------|
| TARGET | File path to improve | Yes |
| REFERENCES | File paths or directory of gold-standard examples | Yes |
| INPUTS | Test inputs — topics, prompts, or scenarios to generate with. If omitted, derive from REFERENCES (same topics). | No |
| EVALS | Evaluation criteria checklist | Yes |
| MAX_ITERATIONS | Stop after N iterations | No (default: 5) |

Example:

```
/iterative-eval
TARGET: config/prompts/script_writing.txt
REFERENCES: examples/4.txt, examples/6.txt, examples/8.txt, examples/12.txt, examples/20.txt
EVALS:
- Hook speed: first 2 lines grab attention
- Dialogue drive: characters push the story
- Colloquial authenticity: sounds like telling a friend
- Reference similarity: overall closeness to gold standard
MAX_ITERATIONS: 5
```

## Process

### Phase 0: Analyze Gap

1. Read TARGET and all REFERENCES.
2. Identify the **biggest gap** between what TARGET produces and what REFERENCES look like.
3. Derive INPUTS from REFERENCES if not provided (use the same topics/scenarios).
4. Present the gap analysis to the user and propose the first single change.
5. Wait for user approval before proceeding.

### Phase 1: Prepare Variants

1. **Variant A** = current TARGET (unchanged).
2. **Variant B** = TARGET with exactly ONE change applied.
3. Save both to a temp directory (e.g., `/tmp/eval-harness/iterN/`).
4. Verify the diff is minimal — if more than one logical change, split it.

### Phase 2: Parallel Generation

For each INPUT, launch two subagents in parallel (single message):
- One uses Variant A as its system prompt
- One uses Variant B as its system prompt
- Each saves output to `/tmp/eval-harness/iterN/topicN_variant_{a,b}.json`

Total subagents = `len(INPUTS) × 2`, all launched in one parallel message.

### Phase 3: Judge Evaluation

Launch a single judge subagent (prefer opus-level model):

1. **Read all REFERENCES** to establish the gold standard.
2. **Anonymize**: Randomly assign Variant A/B outputs to Option 1/Option 2.
3. For each INPUT, compare Option 1 vs Option 2 on every EVAL criterion.
4. For each INPUT, judge which option is **closer to its reference**.
5. Declare per-INPUT winner and overall winner.

Judge output format per INPUT:

```
### Topic: [name]
| Criterion | Option 1 | Option 2 | Winner |
|-----------|----------|----------|--------|
| ...       | [note]   | [note]   | Option X / TIE |

Topic Winner: Option X (N/M criteria)
```

Overall summary with reverse-mapped results.

### Phase 4: Adopt or Reject

1. **Reverse-map** Option 1/2 back to Variant A/B.
2. Count wins: how many INPUTs did B win vs A?
3. **Adoption rule**:
   - B wins majority → **adopt** (update TARGET file)
   - TIE → **adopt** (change doesn't hurt, may help on unseen inputs)
   - A wins majority → **reject** (keep TARGET unchanged)
4. If adopted: update the actual TARGET file, commit with message describing the change.
5. Report result to user.

### Phase 5: Diagnose and Plan Next Change

Based on the judge's feedback:

1. Identify the **single biggest remaining gap** between generated outputs and REFERENCES.
2. Look at which EVAL criteria are still weak.
3. Look at judge notes about what ALL generated scripts lack vs references.
4. Propose exactly ONE change to address the top gap.
5. Present to user and wait for approval.
6. If approved → go to Phase 1 with the new change.

### Stop Conditions

Stop the iteration loop when any of these is true:

- MAX_ITERATIONS reached
- Judge reports no significant gap remaining between outputs and references
- User requests stop
- Last N iterations (N ≥ 2) were all rejected — the approach may need rethinking, surface this to the user

## Key Rules

- **ONE change per iteration.** This is non-negotiable. If you think two changes are needed, pick the one with higher expected impact.
- **Same INPUTS every iteration.** Changing inputs between iterations invalidates comparison.
- **Always anonymize** before the judge sees outputs. Always reverse-map before showing the user.
- **Phase 2 subagents MUST launch in a single parallel message.** Sequential generation wastes time and may introduce ordering bias.
- **Judge must read REFERENCES** every time. The judge compares generated output to the actual reference, not to an abstract standard.
- **Adopt on TIE.** A change that doesn't hurt is worth keeping — it may help on inputs not in the test set.
- **Never skip the gap diagnosis.** Phase 5 is what makes this iterative instead of random. The judge's feedback drives what to change next.

## Report Format

After each iteration:

```
## Iteration N Report

**Change:** [one-sentence description of what was changed]
**Diff:** [the specific lines changed in TARGET]

### Results
| Input | Winner | Score |
|-------|--------|-------|
| ...   | A/B    | N/M   |

**Overall: [A/B] wins N:M → [ADOPTED/REJECTED]**

### Judge Feedback
- [Key observation about remaining gaps]
- [What generated outputs still lack vs references]

### Next Proposed Change
[One sentence describing the next change, targeting the biggest remaining gap]
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Bundling multiple changes in one iteration | Split into separate iterations — one change each |
| Changing INPUTS between iterations | Keep inputs fixed for valid comparison |
| Skipping gap analysis after rejection | Rejected changes still provide signal — analyze why |
| Adopting without reverse-mapping | Always reverse-map before deciding |
| Continuing after 2+ consecutive rejections | Stop and rethink the approach with the user |
