---
description: "Initialize a PRD for Ralph loop execution"
---

# Ralph Init

You are initializing a Ralph loop PRD (Product Requirements Document).

The user's task description: $ARGUMENTS

## Your Job

1. Analyze the task description
2. Break it into well-sized user stories (each completable in one focused iteration)
3. Create `.ralph/prd.json` with the structure below
4. Create `.ralph/progress.txt` with initial content
5. Report the summary

## `.ralph/prd.json` Format

```json
{
  "project": "[Project name from context]",
  "branchName": "ralph/[feature-name-kebab-case]",
  "description": "[Task description]",
  "userStories": [
    {
      "id": "US-001",
      "title": "[Short title]",
      "description": "As a [user], I want to [action] so that [benefit].",
      "acceptanceCriteria": [
        "Specific criterion 1",
        "Tests pass",
        "Typecheck passes"
      ],
      "priority": 1,
      "status": "open",
      "startedAt": null,
      "completedAt": null,
      "passes": false
    }
  ]
}
```

**Status field values:**

- `"open"` - Story not yet started (default)
- `"in_progress"` - AI is actively working on this story
- `"done"` - Story completed successfully

**Timestamp fields:**

- `startedAt` - ISO timestamp when status changes to "in_progress", null otherwise
- `completedAt` - ISO timestamp when status changes to "done", null otherwise
- `passes` - Boolean, true when story passes all acceptance criteria (kept for backward compatibility)

## `.ralph/progress.txt` Initial Content

```text
# Ralph Progress Log
Started: [ISO timestamp]

## Codebase Patterns
(No patterns discovered yet)

---
```

## Story Guidelines

- **Right-sized**: Each story should be completable in one focused session
- **Verifiable**: Include "Tests pass" and "Typecheck passes" in acceptance criteria
- **Independent**: Minimize dependencies between stories
- **Priority order**: Foundational work (DB, types, models) before features, features before UI
- **Include testing stories**: If the task needs tests, make them explicit stories

## After Creating Files

Report:

- Total number of stories
- Story list with IDs and titles
- Suggested command: `/ralph-loop` or `/ralph-loop --max-iterations N`
