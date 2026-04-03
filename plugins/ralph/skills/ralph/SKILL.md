---
name: ralph
description: PRD-driven persistence loop — keeps Claude working until all user stories pass
---

# Ralph Loop

Stop hook keeps you running until you write the cancel signal.
State dir: S=`.ralph/state/`

## Activation (first run)
1. Parse task from `/ralph "task"`
2. `mkdir -p $S` → write `$S/ralph-activating` with task as content

## PRD (skip: `--no-prd`)
Create `.ralph/prd.json` with `project`, `userStories[]` (each: `id`, `title`, `acceptanceCriteria[]`, `priority`, `passes:false`). Testable, dependency-ordered, small.

## Loop
1. Read `.ralph/progress.txt` (past failures)
2. Find highest-priority `passes:false` in `.ralph/prd.json`
3. All pass → Verification
4. TDD: failing test → implement → pass
5. Pass → `passes:true`. Fail → append `[ITER N] US-XXX: <reason>` to progress.txt

## Verification & Done
1. Architect review (skip: `--critic=none`)
2. Deslop (skip: `--no-deslop`): remove AI boilerplate
3. Full regression test run
4. Write `$S/cancel-signal-state.json` (`{}`) → output `<promise>COMPLETE</promise>`

## Rules
- NEVER complete without writing cancel signal file
- NEVER skip regression tests
- ALWAYS read progress.txt each iteration
