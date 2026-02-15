---
description: "Explain Ralph Wiggum technique and available commands"
---

# Ralph Wiggum Plugin Help

Please explain the following to the user:

## What is the Ralph Wiggum Technique?

The Ralph Wiggum technique is an iterative development methodology based on continuous
AI loops, pioneered by Geoffrey Huntley and the snarktank community (inspired by the
original snarktank/ralph project).

**Core concept:**

```bash
while :; do
  claude --print PROMPT.md
done
```

The same prompt is fed to Claude repeatedly. The "self-referential" aspect comes
from Claude seeing its own previous work in the files and git history, not from
feeding output back as input.

**Each iteration:**

1. A fresh Claude instance receives the SAME prompt
2. Works on the task, modifying files
3. Exits (process completes)
4. Bash loop spawns another fresh instance
5. Claude sees its previous work in the files
6. Iteratively improves until completion

The technique is described as "deterministically bad in an undeterministic world" -
failures are predictable, enabling systematic improvement through prompt tuning.

## Available Commands

### /ralph-init "description"

Create a PRD (Product Requirements Document) from a task description.

**Usage:**

```text
/ralph-init "Build a REST API for todos"
```

**How it works:**

1. Analyzes the task description
2. Breaks it into user stories (completable in one iteration)
3. Creates `.ralph/prd.json` with stories and acceptance criteria
4. Creates `.ralph/progress.txt` for tracking
5. Reports the story breakdown

---

### /ralph-loop [max-iterations]

Start the Ralph loop with a bash script.

**Usage:**

```text
/ralph-loop
/ralph-loop 20
```

**How it works:**

1. Reads `.ralph/prd.json` for user stories
2. Spawns fresh `claude --print` instances in a bash loop
3. Each instance implements one story, runs tests, commits if passing
4. Loop exits when all stories pass or max iterations reached
5. Progress tracked in `.ralph/progress.txt`

**Default:** 10 iterations

**Monitoring progress:**

```bash
tail -f .ralph/progress.txt
```

---

### /cancel-ralph

Cancel an active Ralph loop.

**Usage:**

```text
/cancel-ralph
```

**How it works:**

- Checks for `.ralph/ralph.pid` (loop process ID)
- Kills the bash loop process
- Removes PID file
- Reports cancellation

---

## How It Works

### The New Architecture

This plugin implements Ralph using a **bash loop + fresh instances** approach:

1. **Initialize**: Run `/ralph-init` to create PRD with user stories
2. **Start loop**: Run `/ralph-loop` to begin bash loop
3. **Iterate**: Each iteration spawns a fresh Claude instance
4. **Track**: Progress logged to `.ralph/progress.txt`
5. **Complete**: Loop exits when all stories pass or max iterations reached

### Self-Reference Mechanism

The "loop" doesn't mean Claude talks to itself. It means:

- Same prompt repeated across fresh instances
- Claude's work persists in files and git history
- Each iteration sees previous attempts
- Builds incrementally toward goal

### Fresh Instance Benefits

- Clean state each iteration (no session pollution)
- Natural exit after each story
- Better error isolation
- Easier debugging

## Example

### Building a Feature

```text
/ralph-init "Add user authentication with JWT"
```

Claude breaks this into stories:

- US-001: Create JWT utilities
- US-002: Add login endpoint
- US-003: Add auth middleware
- US-004: Write tests

```text
/ralph-loop 20
```

The loop:

- Implements US-001, runs tests, commits
- Implements US-002, runs tests, commits
- Continues until all stories pass or 20 iterations reached

## When to Use Ralph

**Good for:**

- Well-defined tasks with clear success criteria
- Tasks requiring iteration and refinement
- Test-driven development workflows
- Greenfield projects
- Features that can be broken into small stories

**Not good for:**

- Tasks requiring human judgment or design decisions
- One-shot operations
- Tasks with unclear success criteria
- Debugging production issues (use targeted debugging instead)

## Learn More

- Original technique: <https://ghuntley.com/ralph/>
- Inspiration: <https://github.com/snarktank/ralph>
