---
name: ralph
description: PRD-driven persistence loop — keeps Claude working until all user stories pass verification
---

# Ralph Loop

Stop hook keeps you running until you write the cancel signal file.

## Activation (first run)
1. Parse task from `/ralph "task"`
2. `mkdir -p .ralph/state/`
3. Write `.ralph/state/ralph-activating` with task as content

## PRD (skip: `--no-prd`)
Create `.ralph/prd.json`:
```json
{"project":"name","description":"task","userStories":[{"id":"US-001","title":"...","acceptanceCriteria":["testable"],"priority":1,"passes":false}]}
```
Rules: testable criteria, dependency-ordered, small scope.

## Iteration Loop
1. Read `.ralph/progress.txt` (learnings from past failures)
2. Find highest-priority `passes: false` story in `.ralph/prd.json`
3. All pass → Completion Verification
4. TDD: failing test → implement → pass
5. Run tests. Pass → `passes: true`. Fail → append `[ITER N] US-XXX: <reason>` to progress.txt

## Completion Verification
1. Architect review (skip: `--critic=none`)
2. Deslop pass (skip: `--no-deslop`): remove AI boilerplate
3. Full regression test run

## Done
1. Write `.ralph/state/cancel-signal-state.json` (`{}`)
2. Output `<promise>COMPLETE</promise>`

## Rules
- NEVER complete without writing cancel signal file
- NEVER skip regression tests
- ALWAYS read progress.txt each iteration
