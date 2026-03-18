---
name: iterate
description: Use when improving anything incrementally — prompts, code, configs, docs — through repeated single-change cycles with verification after each step.
---

# iterate

Improve a target through repeated cycles of: **one change → verify → adopt or reject → diagnose next**.

Works for any artifact where you can verify whether a change helped: LLM prompts, code, configs, templates, documentation.

## When to Use

- Improving an LLM prompt toward reference-quality outputs
- Refactoring code in safe, testable steps
- Tuning a config file for better behavior
- Any "make X better" task where progress should be incremental and verified

## When NOT to Use

- One-off comparison of two approaches → use `eval-harness`
- Task is a single clear fix (no iteration needed)
- No way to verify whether a change helped

## Core Principle: One Change at a Time

Each iteration makes exactly ONE small, testable change. Never bundle.

Why: bundled changes hide signal. If you change two things and the result improves, you don't know which one helped. If it gets worse, you don't know which one hurt. One change = clear signal.

## Input

| Field | Description | Required |
|-------|-------------|----------|
| TARGET | What to improve (file path, code area, etc.) | Yes |
| GOAL | What "better" looks like — reference files, test suite, acceptance criteria | Yes |
| VERIFICATION | How to check if a change helped (see Verification Methods) | Yes |
| MAX_ITERATIONS | Stop after N cycles | No (default: 5) |

## Verification Methods

The skill supports any verification that produces a clear pass/fail or better/worse signal:

| Method | How it works | Example |
|--------|-------------|---------|
| `test` | Run a test command, check pass/fail | `make test`, `bats tests/`, `go test ./...` |
| `build` | Run a build command, check success | `make build`, `npm run build` |
| `judge` | A/B comparison via model judge against references | Prompt tuning with gold-standard examples |
| `user` | Show the change and ask the user | Subjective improvements, design changes |
| `metric` | Run a command that outputs a number, check improvement | Performance benchmarks, coverage % |
| `composite` | Combine multiple methods | `test` + `judge`, `build` + `metric` |

For `judge` verification: generate outputs from both variants in parallel, anonymize, have a judge compare against references. Same as what `eval-harness` does, but embedded in the iteration loop.

## Process

### Step 0: Analyze Gap

1. Read TARGET and GOAL.
2. Identify the **single biggest gap** between current state and goal.
3. Propose one change to address it.
4. Wait for user approval.

### Step 1: Apply One Change

1. Make exactly ONE change to TARGET.
2. Keep a record of what changed and why.

### Step 2: Verify

Run the VERIFICATION method:

- **test/build/metric**: Run command, capture result.
- **judge**: Generate outputs with both old and new TARGET, anonymize, judge compares against GOAL references.
- **user**: Show diff, ask "is this better?"
- **composite**: Run all methods, all must pass.

### Step 3: Adopt or Reject

Based on verification result:

- **Pass / Better** → adopt the change. Commit if appropriate.
- **Neutral / TIE** → adopt (doesn't hurt, may help on unseen cases).
- **Fail / Worse** → reject. Revert the change.

### Step 4: Diagnose Next Change

This is what makes it iterative instead of random:

1. Look at verification feedback — what specifically is still wrong or suboptimal?
2. Identify the **single biggest remaining gap**.
3. Propose one change.
4. Wait for user approval.
5. Go to Step 1.

### Stop Conditions

Stop when any of these is true:

- MAX_ITERATIONS reached
- Verification shows no significant remaining gap
- User requests stop
- 2+ consecutive rejections — stop and rethink approach with user

## Iteration Report

After each cycle, output:

```
## Iteration N

**Change:** [one sentence]
**Verification:** [method used] → [result]
**Decision:** ADOPTED / REJECTED

**Remaining gap:** [what's still not right]
**Next proposed change:** [one sentence]
```

## Key Rules

- **ONE change per iteration.** If two changes seem needed, pick the higher-impact one.
- **Always verify.** Never adopt a change without checking.
- **Feedback drives next change.** Don't pre-plan all iterations — let verification results guide you.
- **Stop on consecutive rejections.** Two rejections in a row means the current approach isn't working.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Bundling multiple changes | Split — one change per iteration |
| Pre-planning all changes upfront | Let each verification result inform the next change |
| Skipping verification ("it's obviously better") | Always verify. Obvious improvements often aren't. |
| Continuing after repeated rejections | Stop, discuss with user, try a different angle |
| Making the same rejected change again | A rejection provides signal — change your approach |
