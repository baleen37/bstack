# Ralph Agent Instructions

You are executing iteration {{ITERATION}} of {{MAX}} in a Ralph loop.

## Your Task

1. Read the PRD at `.ralph/prd.json` to find user stories
2. Read the progress log at `.ralph/progress.txt` (check Codebase Patterns section first)
3. Read the guardrails at `.ralph/guardrails.md` (check Lessons Learned and Patterns Discovered sections)
4. Find the **highest priority** story where `status` is not `"done"`
5. When starting work on a story:
   - Update `.ralph/prd.json`: set `status: "in_progress"` and
     `startedAt: "<current ISO timestamp>"` for this story
6. Implement ONLY that one story
7. Run quality checks (e.g., typecheck, lint, test - use whatever your project requires)
8. Update CLAUDE.md files if you discover reusable patterns (see below)
9. If checks pass:
   - Commit ALL changes with message: `feat: [Story ID] - [Story Title]`
   - Update `.ralph/prd.json`: set `status: "done"`,
     `completedAt: "<current ISO timestamp>"`, and `passes: true` for this story
   - Append your progress to `.ralph/progress.txt`

10. If checks fail:
    - Append what went wrong to `.ralph/progress.txt`
    - Do NOT mark the story as done (keep status as "in_progress" or revert to "open" if appropriate)

11. After processing one story, check if ALL stories have `status: "done"`
    - If yes: output exactly `<promise>COMPLETE</promise>`
    - If no: stop (next iteration will pick up the next story)

## Progress Report Format

APPEND to .ralph/progress.txt (never replace, always append):

```text
## [Date/Time] - [Story ID]

- What was implemented
- Files changed

**Learnings for future iterations:**
- Patterns discovered (e.g., "this codebase uses X for Y")
- Gotchas encountered (e.g., "don't forget to update Z when changing W")
- Useful context (e.g., "the evaluation panel is in component X")

---
```

The learnings section is critical - it helps future iterations avoid repeating mistakes and understand the codebase better.

## Guardrails Update Format

APPEND to .ralph/guardrails.md (never replace, always append) when you discover important lessons or patterns:

```text
## [Date/Time]

### Lessons Learned
- Example: Component X requires prop Y to render correctly
- Example: Tests fail if service Z is not mocked properly

### Patterns Discovered
- Example: All API calls go through the service layer
- Example: State management uses pattern X for async operations

---
```

Only add entries to guardrails.md when you discover **generalizable lessons** that would help
future iterations avoid common pitfalls or understand the codebase architecture better.

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know,
add it to the `## Codebase Patterns` section at the TOP of .ralph/progress.txt
(create it if it doesn't exist). This section should consolidate the most
important learnings:

```text
## Codebase Patterns

- Example: Use `sql` template for aggregations
- Example: Always use `IF NOT EXISTS` for migrations
- Example: Export types from actions.ts for UI components
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update CLAUDE.md Files

Before committing, check if any edited files have learnings worth preserving in nearby CLAUDE.md files:

1. **Identify directories with edited files** - Look at which directories you modified
2. **Check for existing CLAUDE.md** - Look for CLAUDE.md in those directories or parent directories
3. **Add valuable learnings** - If you discovered something future developers/agents should know:
   - API patterns or conventions specific to that module
   - Gotchas or non-obvious requirements
   - Dependencies between files
   - Testing approaches for that area
   - Configuration or environment requirements

**Examples of good CLAUDE.md additions:**

- "When modifying X, also update Y to keep them in sync"
- "This module uses pattern Z for all API calls"
- "Tests require the dev server running on PORT 3000"
- "Field names must match the template exactly"

**Do NOT add:**

- Story-specific implementation details
- Temporary debugging notes
- Information already in .ralph/progress.txt

Only update CLAUDE.md if you have **genuinely reusable knowledge** that would help future work in that directory.

## Quality Requirements

- ALL commits must pass your project's quality checks (typecheck, lint, test)
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow existing code patterns

## Browser Testing (If Available)

For any story that changes UI, verify it works in the browser if you have browser testing tools configured (e.g., via MCP):

1. Navigate to the relevant page
2. Verify the UI changes work as expected
3. Take a screenshot if helpful for the progress log

If no browser tools are available, note in your progress report that manual browser verification is needed.

## Important

- Work on ONE story per iteration. Do not try to do multiple stories.
- Always run tests before marking a story as passing.
- Never mark a story as passing if tests fail.
- Never delete or skip tests.
- Commit frequently.
- Keep CI green.
- Read the Codebase Patterns section in .ralph/progress.txt before starting.
- Read .ralph/guardrails.md before starting to avoid repeating past mistakes.
- Append lessons learned and patterns discovered to .ralph/guardrails.md after each story.
