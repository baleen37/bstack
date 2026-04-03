---
name: ralph
description: PRD-driven persistence loop — keeps Claude working until all user stories pass
---

# Ralph Loop

Stop hook keeps you running until you write the cancel signal.
S=`.ralph/state/`

## Activation (first run)
1. Parse task from `/ralph "task"`
2. `mkdir -p $S` → write `$S/ralph-activating` with task content

## PRD
Create `.ralph/prd.json`: `project`, `userStories[]` (each: `id`, `title`, `acceptanceCriteria[]`, `priority`, `passes:false`). Testable, dependency-ordered, small.

## Loop
1. Read `.ralph/progress.txt` if it exists (skip on first iteration)
2. Find highest-priority `passes:false` in `.ralph/prd.json`
3. All pass → Verify & Done
4. TDD: failing test → implement → pass
5. Pass → `passes:true`. Fail → append `[ITER N] US-XXX: <reason>` to progress.txt

## Verify & Done
1. Architect review: design quality, edge cases, code clarity
2. Deslop: remove unnecessary comments, abstractions, verbose error handling
3. Full regression test run — must pass
4. Write `$S/cancel-signal-state.json` (`{}`) then reply `<promise>COMPLETE</promise>`

**Rules:** ALWAYS read progress.txt each iteration. NEVER skip regression tests or cancel signal.
**Flags:** `--no-prd` `--critic=none` `--no-deslop`
