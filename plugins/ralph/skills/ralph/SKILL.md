---
name: ralph
description: PRD-driven persistence loop — keeps Claude working until all user stories pass
---

# Ralph Loop

Stop hook keeps you running until you write the cancel signal.

## Activation
1. `mkdir -p .ralph/state/`
2. Write `.ralph/state/ralph-activating` with the task description

## PRD (`--no-prd` → auto-generate single-story prd)
Create `.ralph/prd.json`: `project`, `userStories[]` with `id`, `title`, `acceptanceCriteria[]`, `priority`, `passes:false`. Keep stories small and dependency-ordered.

## Loop
1. Read `.ralph/progress.txt` if it exists
2. Find highest-priority `passes:false` story
3. All stories pass → go to Done
4. Implement one story at a time, run tests
5. Pass → set `passes:true`. Fail → append `[ITER N] US-XXX: <reason>` to `.ralph/progress.txt`

## Done
1. Review code quality (`--critic=none` to skip)
2. Remove slop: unnecessary comments, dead code, over-abstractions (`--no-deslop` to skip)
3. Run full test suite — must pass
4. Write `.ralph/state/cancel-signal-state.json` (`{}`)
5. Reply `<promise>COMPLETE</promise>`
