---
name: ralph
description: PRD-driven persistence loop — keeps Claude working until all user stories pass verification
---

# Ralph Loop

You are executing the Ralph persistence loop. Your job is to implement the task completely. The Stop hook will keep you running until you write the cancel signal file.

## Activation (first run only)

1. Parse the task from the invocation: `/ralph "your task description"`
2. Create `.ralph/state/` directory if it does not exist
3. Write `.ralph/state/ralph-activating` with the task description as content
4. Proceed to PRD writing

## PRD Writing (skip with `--no-prd`)

Create `.ralph/prd.json` with this structure:

```json
{
  "project": "<project name>",
  "description": "<task description>",
  "userStories": [
    {
      "id": "US-001",
      "title": "<story title>",
      "description": "<what the user wants>",
      "acceptanceCriteria": ["<testable criterion>", "..."],
      "priority": 1,
      "passes": false
    }
  ]
}
```

Rules:
- Each story must have clear, testable acceptance criteria
- Order stories by dependency (foundational first)
- Keep stories small — one story = one focused piece of functionality

## Story Execution Loop

On each iteration:

1. Read `.ralph/progress.txt` for learnings from previous iterations
2. Read `.ralph/prd.json` and find the highest-priority story with `passes: false`
3. If all stories have `passes: true`, proceed to Completion Verification
4. Implement the story following TDD: write failing test → implement → make pass
5. Run the project's test suite
6. If tests pass: set `passes: true` for this story in `prd.json`
7. If tests fail: append learnings to `.ralph/progress.txt`:
   ```
   [ITERATION N] Story US-XXX failed: <what went wrong> / <what to try next>
   ```

## Completion Verification

When all stories have `passes: true`:

1. **Architect review** (skip with `--critic=none`): Review the full implementation for design quality, edge cases, and code clarity. Fix any issues found.
2. **Deslop pass** (skip with `--no-deslop`): Remove AI-generated boilerplate, overly verbose comments, unnecessary abstractions, and any code that exists for no clear reason.
3. **Regression test run**: Run the full test suite. All tests must pass.

## Completion

When verification passes:

1. Write `.ralph/state/cancel-signal-state.json` (content can be empty `{}`)
2. Output: `<promise>COMPLETE</promise>`

The Stop hook will detect the cancel signal and exit the loop.

## Flags

- `--no-prd` — Skip PRD writing, treat the task description as the single story
- `--no-deslop` — Skip the deslop pass
- `--critic=none` — Skip architect review (default: architect)

## Important

- Never declare completion without writing the cancel signal file
- Never skip the regression test run
- Read `progress.txt` at the start of every iteration — past failures contain critical information
