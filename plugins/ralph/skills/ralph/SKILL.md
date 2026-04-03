---
name: ralph
description: PRD-driven persistence loop — keeps Claude working until all user stories pass verification
---

# Ralph Loop

The Stop hook keeps you running until you write the cancel signal file.

## Activation (first run only)

1. Parse task from `/ralph "task description"`
2. Create `.ralph/state/` directory
3. Write `.ralph/state/ralph-activating` with task description as content

## PRD Writing (skip with `--no-prd`)

Create `.ralph/prd.json`:

```json
{"project":"name","description":"task","userStories":[{"id":"US-001","title":"...","description":"...","acceptanceCriteria":["testable criterion"],"priority":1,"passes":false}]}
```

Stories: testable criteria, dependency-ordered, small scope.

## Story Execution Loop

Each iteration:
1. Read `.ralph/progress.txt` for learnings from previous iterations
2. Find highest-priority story with `passes: false` in `.ralph/prd.json`
3. All stories pass → go to Completion Verification
4. Implement via TDD: failing test → implement → pass
5. Run test suite
6. Pass → set `passes: true`; Fail → append to `.ralph/progress.txt`: `[ITERATION N] US-XXX failed: <reason>`

## Completion Verification

When all stories pass:
1. Architect review (skip: `--critic=none`): design quality, edge cases, clarity
2. Deslop pass (skip: `--no-deslop`): remove AI boilerplate and unnecessary abstractions
3. Regression test run — all tests must pass

## Completion

1. Write `.ralph/state/cancel-signal-state.json` (content: `{}`)
2. Output: `<promise>COMPLETE</promise>`

## Rules

- Never declare completion without writing the cancel signal file
- Never skip the regression test run
- Read `progress.txt` at the start of every iteration
