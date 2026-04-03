---
name: ralph
description: PRD-driven persistence loop — keeps Claude working until all user stories pass
---

# Ralph Loop

Stop hook keeps you running until you write the cancel signal.

## Activation (first run)
1. Parse task from `/ralph "task"`
2. `mkdir -p .ralph/state/` → write `.ralph/state/ralph-activating` with task as content

## PRD (skip: `--no-prd`)
Create `.ralph/prd.json` with `project`, `userStories[]` where each story has `id`, `title`, `acceptanceCriteria[]`, `priority`, `passes:false`. Testable criteria, dependency-ordered, small scope.

## Loop
1. Read `.ralph/progress.txt` (past failure learnings)
2. Find highest-priority `passes:false` in `.ralph/prd.json`
3. All pass → Verification
4. TDD: failing test → implement → pass
5. Pass → `passes:true`. Fail → append `[ITER N] US-XXX: <reason>` to progress.txt

## Verification
1. Architect review (skip: `--critic=none`)
2. Deslop (skip: `--no-deslop`): remove AI boilerplate
3. Full regression test run

## Done
1. Write `.ralph/state/cancel-signal-state.json` (`{}`)
2. Output `<promise>COMPLETE</promise>`

## Rules
- NEVER complete without writing cancel signal file
- NEVER skip regression tests
- ALWAYS read progress.txt each iteration
