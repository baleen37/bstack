# Ralph Wiggum Plugin

Implementation of the Ralph Wiggum technique for iterative, self-referential AI development loops in Claude Code.

## What is Ralph?

Ralph is a development methodology based on continuous AI agent loops. As Geoffrey
Huntley describes it: **"Ralph is a Bash loop"** - a simple `while true` that repeatedly
feeds an AI agent a prompt file, allowing it to iteratively improve its work until
completion.

The technique is named after Ralph Wiggum from The Simpsons, embodying the philosophy of persistent iteration despite setbacks.

### Core Concept

This plugin implements Ralph using a **bash loop + fresh instances** approach:

```bash
# You run ONCE:
/ralph-init "Your task description"

# Then:
/ralph-loop

# Behind the scenes, a bash loop runs:
while true; do
  claude --print PROMPT.md
done
```

Each iteration spawns a **fresh Claude instance** that receives the SAME prompt.
The "self-referential" aspect comes from Claude seeing its own previous work
in the files and git history, not from feeding output back as input.

This creates a **self-referential feedback loop** where:

- The prompt never changes between iterations
- Claude's previous work persists in files
- Each iteration sees modified files and git history
- Claude autonomously improves by reading its own past work in files
- Fresh instances provide clean state each iteration (no session pollution)

## Quick Start

```bash
# 1. Initialize a PRD with user stories
/ralph-init "Build a REST API for todos. Requirements: CRUD operations, input validation, tests."

# 2. Start the loop (default 10 iterations)
/ralph-loop

# Or specify max iterations
/ralph-loop 50

# 3. Monitor progress in another terminal
tail -f .ralph/progress.txt

# 4. Cancel if needed
/cancel-ralph
```

Claude will:

- Implement one user story per iteration
- Run tests and quality checks
- Commit work if tests pass
- Continue until all stories pass or max iterations reached

## Architecture

### The .ralph Directory

Ralph uses a `.ralph/` directory for state management:

```text
.ralph/
├── prd.json         # Product Requirements Document with user stories
├── progress.txt     # Progress log with learnings from each iteration
└── ralph.pid        # Process ID of active loop (exists only while running)
```

### PRD Format

The `prd.json` file contains your task broken into user stories:

```json
{
  "project": "my-project",
  "branchName": "ralph/add-todo-api",
  "description": "Build a REST API for todos",
  "userStories": [
    {
      "id": "US-001",
      "title": "Create todo model",
      "description": "As a developer, I want a todo data model so that I can store todos.",
      "acceptanceCriteria": [
        "Todo model with id, title, completed fields",
        "Tests pass",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
```

### Iteration Workflow

Each iteration follows this pattern:

1. Fresh Claude instance starts
2. Reads `.ralph/prd.json` to find user stories
3. Reads `.ralph/progress.txt` for previous learnings
4. Finds the highest-priority story where `passes` is `false`
5. Implements ONLY that one story
6. Runs tests and quality checks (typecheck, lint, test)
7. If checks pass:
   - Commits with message: `feat: [STORY_ID] - Story Title`
   - Updates `.ralph/prd.json`: sets `passes: true` for this story
   - Appends learnings to `.ralph/progress.txt`
8. If checks fail:
   - Appends what went wrong to `.ralph/progress.txt`
   - Does NOT mark the story as passing
9. Checks if ALL stories have `passes: true`:
   - If yes: outputs `<promise>COMPLETE</promise>` (loop exits)
   - If no: stops (next iteration picks up the next story)

### Prompt Template

The `scripts/prompt.md` template is used for each iteration:

```markdown
You are executing iteration {{ITERATION}} of {{MAX}} in a Ralph loop.

## Instructions

1. Read `.ralph/prd.json` to find user stories
2. Read `.ralph/progress.txt` for learnings from previous iterations
3. Find the highest-priority story where `passes` is `false`
4. Implement ONLY that one story
5. Run tests and quality checks (typecheck, lint, test)
6. If checks pass:
   - Commit with message: `feat: [STORY_ID] - Story Title`
   - Update `.ralph/prd.json`: set `passes: true` for this story
   - Append what you learned to `.ralph/progress.txt`
7. If checks fail:
   - Append what went wrong to `.ralph/progress.txt`
   - Do NOT mark the story as passing
8. After processing one story, check if ALL stories have `passes: true`
   - If yes: output exactly `<promise>COMPLETE</promise>`
   - If no: stop (next iteration will pick up the next story)

## Rules

- Implement ONE story per iteration. Do not try to do multiple stories.
- Always run tests before marking a story as passing.
- Never mark a story as passing if tests fail.
- Never delete or skip tests.
- Write useful learnings to progress.txt — the next iteration depends on them.
```

## Commands

### /ralph-init "description"

Initialize a PRD (Product Requirements Document) from a task description.

**Usage:**

```bash
/ralph-init "Build a REST API for todos with CRUD operations, input validation, and tests."
```

**What it does:**

- Analyzes the task description
- Breaks it into user stories (completable in one iteration)
- Creates `.ralph/prd.json` with stories and acceptance criteria
- Creates `.ralph/progress.txt` for tracking
- Reports the story breakdown

**Story guidelines:**

- **Right-sized**: Each story should be completable in one focused session
- **Verifiable**: Include "Tests pass" and "Typecheck passes" in acceptance criteria
- **Independent**: Minimize dependencies between stories
- **Priority order**: Foundational work (DB, types, models) before features, features before UI

### /ralph-loop [max-iterations]

Start the Ralph loop with a bash script.

**Usage:**

```bash
# Default: 10 iterations
/ralph-loop

# Custom max iterations
/ralph-loop 20
```

**What it does:**

- Reads `.ralph/prd.json` for user stories
- Spawns fresh `claude --print` instances in a bash loop
- Each instance implements one story, runs tests, commits if passing
- Loop exits when all stories pass or max iterations reached
- Progress tracked in `.ralph/progress.txt`

**Monitoring progress:**

```bash
tail -f .ralph/progress.txt
```

### /cancel-ralph

Cancel an active Ralph loop.

**Usage:**

```bash
/cancel-ralph
```

**What it does:**

- Checks for `.ralph/ralph.pid` (loop process ID)
- Kills the bash loop process
- Removes PID file
- Reports cancellation

## Prompt Writing Best Practices

### 1. Clear Task Description

❌ Bad: "Build a todo API and make it good."

✅ Good:

```bash
/ralph-init "Build a REST API for todos. Requirements:
- CRUD operations (create, read, update, delete)
- Input validation (title required, max 100 chars)
- Unit tests for all endpoints
- Integration tests
- API documentation
- Type safety with TypeScript
```

### 2. Right-Sized Stories

When `/ralph-init` creates stories, it should break the task into manageable pieces:

❌ Too big: "Build the entire e-commerce platform"

✅ Right-sized:

- US-001: Setup project structure and dependencies
- US-002: Create product data model
- US-003: Implement product list endpoint
- US-004: Add product creation with validation
- US-005: Write tests for product endpoints

### 3. Include Testing Stories

Make testing explicit:

✅ Good breakdown:

- US-001: Create user model
- US-002: Write unit tests for user model
- US-003: Implement user service
- US-004: Write integration tests for user service
- US-005: Create user API endpoints
- US-006: Write API tests for endpoints

### 4. Set Reasonable Iteration Limits

Always use max-iterations as a safety net:

```bash
# Recommended: Estimate based on story count
# 5 stories × 2-3 iterations per story = 10-15 iterations
/ralph-loop 15

# For larger tasks: 10 stories × 3 iterations = 30 iterations
/ralph-loop 30
```

### 5. Verifiable Acceptance Criteria

Each story should have clear pass/fail criteria:

✅ Good acceptance criteria:

- "Todo model with id, title, completed fields defined"
- "POST /todos creates a todo and returns 201"
- "GET /todos returns array of todos"
- "Tests pass (npm test)"
- "Typecheck passes (npm run typecheck)"

## Complete Example

Let's walk through a complete session building a simple todo API feature.

### Step 1: Initialize the PRD

```bash
/ralph-init "Add a simple todo API with POST /todos to create todos and GET /todos to list them. Use TypeScript, Express, and include tests."
```

Claude breaks this into stories and creates `.ralph/prd.json`:

```json
{
  "project": "my-api",
  "branchName": "ralph/add-todo-api",
  "description": "Add a simple todo API with POST /todos to create todos and GET /todos to list them. Use TypeScript, Express, and include tests.",
  "userStories": [
    {
      "id": "US-001",
      "title": "Setup Express server with TypeScript",
      "description": "As a developer, I want an Express server with TypeScript configured so that I can build API endpoints.",
      "acceptanceCriteria": [
        "Express server listens on port 3000",
        "TypeScript configured",
        "ts-node for development",
        "Tests pass",
        "Typecheck passes"
      ],
      "priority": 1,
      "passes": false
    },
    {
      "id": "US-002",
      "title": "Create todo model and interface",
      "description": "As a developer, I want a todo model so that I can define the structure of todo data.",
      "acceptanceCriteria": [
        "Todo interface with id, title, completed fields",
        "Typecheck passes"
      ],
      "priority": 2,
      "passes": false
    },
    {
      "id": "US-003",
      "title": "Implement POST /todos endpoint",
      "description": "As a user, I want to create todos so that I can track tasks.",
      "acceptanceCriteria": [
        "POST /todos accepts {title: string}",
        "Returns created todo with id and completed: false",
        "Input validation (title required)",
        "Tests pass",
        "Typecheck passes"
      ],
      "priority": 3,
      "passes": false
    },
    {
      "id": "US-004",
      "title": "Implement GET /todos endpoint",
      "description": "As a user, I want to list all todos so that I can see my tasks.",
      "acceptanceCriteria": [
        "GET /todos returns array of todos",
        "Tests pass",
        "Typecheck passes"
      ],
      "priority": 4,
      "passes": false
    }
  ]
}
```

### Step 2: Start the Loop

```bash
/ralph-loop 20
```

### Step 3: Watch Progress

In another terminal:

```bash
tail -f .ralph/progress.txt
```

### Step 4: Iteration Walkthrough

#### Iteration 1 - US-001: Setup Express server

**What happens:**

1. Fresh Claude instance starts
2. Reads `.ralph/prd.json` - finds US-001 is highest priority with `passes: false`
3. Reads `.ralph/progress.txt` - empty (first iteration)
4. Implements Express server setup
5. Runs tests: **FAILS** - test file not created yet

**Progress.txt after iteration 1:**

```text
# Ralph Progress Log
Started: 2026-02-08T12:00:00Z

## Codebase Patterns
(No patterns discovered yet)

## Iteration 1 - US-001: Setup Express server with TypeScript

### Attempted
- Created src/server.ts with Express app
- Added tsconfig.json
- Added package.json with dependencies

### Issues
- Tests failed: No test file found
- Need to add test framework (Jest or similar)

### Next Steps
- Add test framework setup
- Create basic test file

---
```

**prd.json after iteration 1:** US-001 still has `"passes": false` because tests failed.

#### Iteration 2 - US-001: Setup Express server (retry)

**What happens:**

1. Fresh Claude instance starts
2. Reads `.ralph/prd.json` - US-001 still has `passes: false`
3. Reads `.ralph/progress.txt` - sees that test framework was missing
4. Adds Jest configuration and creates test file
5. Runs tests: **PASS**
6. Commits: `feat: US-001 - Setup Express server with TypeScript`
7. Updates `prd.json`: US-001 now has `"passes": true`
8. Appends to `progress.txt`

**Progress.txt after iteration 2:**

```text
## Iteration 2 - US-001: Setup Express server with TypeScript

### Successful
- Added Jest configuration
- Created src/server.test.ts with basic test
- All tests passing
- Typecheck passing

### Committed
- feat: US-001 - Setup Express server with TypeScript

### Learnings
- Project uses Jest for testing
- Test command: npm test
- Typecheck command: npm run typecheck

---
```

**prd.json after iteration 2:** US-001 now has `"passes": true`.

#### Iteration 3 - US-002: Create todo model

**What happens:**

1. Fresh Claude instance starts
2. Reads `.ralph/prd.json` - US-002 is next highest priority with `passes: false`
3. Reads `.ralph/progress.txt` - learns test commands and patterns
4. Creates Todo interface
5. Runs typecheck: **PASS**
6. Commits: `feat: US-002 - Create todo model and interface`
7. Updates `prd.json`: US-002 now has `"passes": true`

**Progress.txt after iteration 3:**

```text
## Iteration 3 - US-002: Create todo model and interface

### Successful
- Created src/models/Todo.ts with interface
- Typecheck passing

### Committed
- feat: US-002 - Create todo model and interface

---
```

#### Iteration 4 - US-003: Implement POST /todos

**What happens:**

1. Fresh Claude instance starts
2. Reads `.ralph/prd.json` - US-003 is next with `passes: false`
3. Reads `.ralph/progress.txt` - learns project structure
4. Implements POST /todos endpoint
5. Runs tests: **FAILS** - missing input validation

**Progress.txt after iteration 4:**

```text
## Iteration 4 - US-003: Implement POST /todos endpoint

### Attempted
- Created POST /todos endpoint in src/routes/todos.ts
- Added in-memory todo storage

### Issues
- Tests failing: Missing input validation for title field
- Need to validate title is not empty
- Need to validate title max length

---
```

#### Iteration 5 - US-003: Fix POST /todos validation

**What happens:**

1. Fresh Claude instance starts
2. Reads `.ralph/prd.json` - US-003 still has `passes: false`
3. Reads `.ralph/progress.txt` - sees validation issues
4. Adds input validation middleware
5. Runs tests: **PASS**
6. Commits: `feat: US-003 - Implement POST /todos endpoint`
7. Updates `prd.json`: US-003 now has `"passes": true`

#### Iteration 6 - US-004: Implement GET /todos

**What happens:**

1. Fresh Claude instance starts
2. Reads `.ralph/prd.json` - US-004 is last story with `passes: false`
3. Reads `.ralph/progress.txt` - learns patterns
4. Implements GET /todos endpoint
5. Runs tests: **PASS**
6. Commits: `feat: US-004 - Implement GET /todos endpoint`
7. Updates `prd.json`: US-004 now has `"passes": true`
8. Checks if ALL stories pass: **YES**
9. Outputs: `<promise>COMPLETE</promise>`

**Loop exits successfully.**

### Final State

**prd.json:** All stories have `"passes": true`

**Git history:**

```text
d69aec5 feat: US-004 - Implement GET /todos endpoint
c8f4b2a feat: US-003 - Implement POST /todos endpoint
a3e7d1c feat: US-002 - Create todo model and interface
7b2c9e0 feat: US-001 - Setup Express server with TypeScript
```

**progress.txt:** Complete log of all iterations with learnings

### Key Observations

**When a story fails tests:**

- Story remains marked as `passes: false`
- Next iteration retries the SAME story
- Progress.txt captures what went wrong
- Each iteration builds on previous work

**When a story passes tests:**

- Story is marked as `passes: true`
- Work is committed
- Next iteration moves to the next story
- Progress.txt captures what was learned

**Fresh instance benefits:**

- Each iteration starts with clean state
- No conversation context pollution
- Progress.txt provides continuity
- Failures are isolated to single iterations

## Philosophy

Ralph embodies several key principles:

### 1. Iteration > Perfection

Don't aim for perfect on first try. Let the loop refine the work. Each iteration
builds on the previous one, incrementally improving toward the goal.

### 2. Failures Are Data

"Deterministically bad" means failures are predictable and informative. Use them
to tune prompts. The `progress.txt` file captures learnings from each failure,
informing subsequent iterations.

### 3. Operator Skill Matters

Success depends on writing good task descriptions and story breakdowns, not just
having a good model. The quality of your `/ralph-init` prompt determines the
quality of the results.

### 4. Persistence Wins

Keep trying until success. The loop handles retry logic automatically. If a story
fails tests, the next iteration sees the failure in `progress.txt` and can fix it.

### 5. Fresh State Benefits

The new architecture uses fresh Claude instances for each iteration:

- **Clean state**: No session context accumulation
- **Natural exit**: Each iteration completes independently
- **Better error isolation**: Failures don't pollute subsequent iterations
- **Easier debugging**: Each iteration is a discrete unit of work

## When to Use Ralph

**Good for:**

- Well-defined tasks with clear success criteria
- Tasks requiring iteration and refinement (e.g., getting tests to pass)
- Test-driven development workflows
- Greenfield projects where you can walk away
- Features that can be broken into small stories
- Tasks with automatic verification (tests, linters, typecheck)

**Not good for:**

- Tasks requiring human judgment or design decisions
- One-shot operations
- Tasks with unclear success criteria
- Production debugging (use targeted debugging instead)
- Tasks that need conversation/clarification

## Real-World Results

- Successfully generated 6 repositories overnight in Y Combinator hackathon testing
- One $50k contract completed for $297 in API costs
- Created entire programming language ("cursed") over 3 months using this approach

## Completion Detection

The loop completes when:

1. **All stories pass**: Every user story in `prd.json` has `passes: true`
2. **Completion promise**: Claude outputs `<promise>COMPLETE</promise>`
3. **Max iterations**: The loop reaches the iteration limit (exits with error)

The loop script checks for the completion promise in Claude's output after each
iteration. When found, it exits cleanly. If max iterations is reached without
completion, the script exits with an error.

## Learn More

- Original technique: <https://ghuntley.com/ralph/>
- Inspiration: <https://github.com/snarktank/ralph>
- Ralph Orchestrator: <https://github.com/mikeyobrien/ralph-orchestrator>

## For Help

Run `/help` in Claude Code for detailed command reference and examples.
