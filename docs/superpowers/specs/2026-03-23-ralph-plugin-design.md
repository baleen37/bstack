# Ralph Plugin Design

**Date:** 2026-03-23
**Status:** Approved
**Scope:** Standalone `plugins/ralph/` plugin for bstack

## Overview

Port OMC's Ralph Loop into bstack as an independent plugin. Ralph is a PRD-driven persistence loop that
keeps Claude working on a task until all user stories pass verification. It works by intercepting
Claude's `Stop` event and returning `decision: "block"` to force continuation.

## Directory Structure

```text
plugins/ralph/
├── .claude-plugin/
│   └── plugin.json          ← plugin metadata
├── hooks/
│   ├── hooks.json           ← Stop hook registration
│   └── ralph-persist.ts     ← Bun script (Stop hook engine)
├── skills/
│   └── ralph/
│       └── SKILL.md         ← /ralph skill (PRD writing + loop protocol)
└── tests/
    └── ralph.bats           ← BATS tests
```

**Runtime state files** (relative to project root):

```text
.ralph/
├── state/
│   ├── ralph-state.json          ← loop state
│   └── cancel-signal-state.json  ← Claude creates this to request loop exit
├── prd.json                      ← user story list with passes status
└── progress.txt                  ← per-iteration learnings log
```

## Claude Code Stop Hook API

Stop hook receives JSON via stdin:

```json
{
  "session_id": "abc123",
  "transcript_path": "~/.claude/projects/.../<id>.jsonl",
  "cwd": "/path/to/project",
  "hook_event_name": "Stop",
  "stop_hook_active": true,
  "last_assistant_message": "..."
}
```

To **block** (keep Claude running): write `{"decision": "block", "reason": "..."}` to stdout and exit 0.

To **allow** (let Claude stop): write nothing to stdout and exit 0.

`cwd` is used to determine the project root and state file paths.
`session_id` is used for session matching against the saved state.
`stop_hook_active` is not used.

## Stop Hook Engine (`ralph-persist.ts`)

Runs on every `Stop` event. Reads JSON from stdin, writes JSON to stdout (or nothing).

### State file path

```text
{cwd}/.ralph/state/ralph-state.json
```

`cwd` is read from stdin. Falls back to `process.cwd()` if not present.

### State initialization

If `.ralph/state/ralph-state.json` does not exist but the hook detects a ralph activation signal
(see SKILL.md Step 1), it creates the state file using `session_id` and `cwd` from stdin, with
`active: true`, `iteration: 0`, `max_iterations: 100`, and the task prompt.

In practice: Claude writes `.ralph/prd.json` and a sentinel file `.ralph/state/ralph-activating`
during `/ralph` skill execution. On the next Stop event, the hook detects this sentinel, creates
`ralph-state.json`, and deletes the sentinel.

### Pass-through conditions (write nothing, exit 0)

1. `.ralph/state/ralph-state.json` does not exist and no `.ralph/state/ralph-activating` sentinel
2. `state.active: false`
3. `state.session_id` does not match `session_id` from stdin
4. `.ralph/state/cancel-signal-state.json` exists → delete it, set `state.active: false`, exit 0
5. `state.last_checked_at` is more than 2 hours ago (stale, same threshold as OMC) → set `state.active: false`, exit 0

### Block logic

All other cases: increment `state.iteration`, update `last_checked_at`, write state, output:

```json
{
  "decision": "block",
  "reason": "[RALPH LOOP - ITERATION N/MAX] Work is not done. Continue working on the task."
}
```

If `iteration >= max_iterations`: extend `max_iterations` by 10, continue blocking. No hard limit —
identical to OMC. The only true exit is via `cancel-signal-state.json`.

### State file schema

```json
{
  "active": true,
  "session_id": "abc123",
  "iteration": 3,
  "max_iterations": 100,
  "started_at": "2026-03-23T10:00:00Z",
  "last_checked_at": "2026-03-23T10:05:00Z",
  "prompt": "original task description"
}
```

`session_id` is read from stdin (`data.session_id`) when the hook first creates the state file.

## Ralph Skill Protocol (`/ralph "task"`)

### Step 1 — Signal activation (first iteration only)

Write `.ralph/state/ralph-activating` with the task description as content. Also write `.ralph/prd.json`
skeleton. The Stop hook detects this sentinel on the next Stop event and creates `ralph-state.json`
using `session_id` from stdin.

### Step 2 — Write PRD (first iteration only, skipped with `--no-prd`)

Create `.ralph/prd.json` with user stories and acceptance criteria.

```json
{
  "project": "...",
  "description": "...",
  "userStories": [
    {
      "id": "US-001",
      "title": "...",
      "description": "...",
      "acceptanceCriteria": ["..."],
      "priority": 1,
      "passes": false
    }
  ]
}
```

### Step 3 — Story execution loop

- Read `.ralph/progress.txt` for learnings from previous iterations
- Select highest-priority story with `passes: false`
- Implement → run tests → if passing, set `passes: true`
- On failure: append learnings to `.ralph/progress.txt`

### Step 4 — Completion verification (after all stories pass)

- Architect review: design and code quality
- Deslop pass: remove AI-generated boilerplate (skipped with `--no-deslop`)
- Full regression test run

### Step 5 — Completion

- Write `.ralph/state/cancel-signal-state.json`
- Output `<promise>COMPLETE</promise>`
- The next Stop hook invocation detects `cancel-signal-state.json` and exits the loop

### Flags

| Flag | Effect |
|------|--------|
| `--no-prd` | Skip PRD writing, execute directly |
| `--no-deslop` | Skip deslop pass |
| `--critic=architect\|none` | Verification reviewer (default: architect) |

## Tests (`tests/ralph.bats`)

All tests run with isolated temporary directories (`$BATS_TMPDIR`).
The hook script is invoked directly with crafted JSON via stdin.

### Unit tests — ralph-persist.ts

- No `state.json` → writes nothing, exits 0
- `active: false` in state → writes nothing, exits 0
- `session_id` mismatch → writes nothing, exits 0
- `cancel-signal-state.json` exists → writes nothing, exits 0, deletes cancel signal, sets `active: false`
- Normal active state → writes `decision: "block"`, increments `iteration`
- `max_iterations` reached → extends by 10, writes `decision: "block"`
- Stale state (>2h) → writes nothing, exits 0, sets `active: false`

### Flow integration tests

**Happy path:**

1. Create `ralph-state.json` with `active: true`, `iteration: 1`, matching `session_id`
2. Invoke hook with matching `session_id` → `decision: "block"`, `iteration` becomes 2
3. Invoke hook again → `decision: "block"`, `iteration` becomes 3
4. Create `cancel-signal-state.json`
5. Invoke hook → writes nothing (exit 0), cancel signal deleted, `state.active: false`

**Session isolation:**

1. Create `ralph-state.json` with `session_id: "session-A"`
2. Invoke hook with `session_id: "session-B"` → writes nothing (orphaned state ignored)

**Stale recovery:**

1. Create `ralph-state.json` with `last_checked_at` set to 3 hours ago
2. Invoke hook → writes nothing, `state.active` set to `false`

**max_iterations extension:**

1. Create `ralph-state.json` with `iteration: 100`, `max_iterations: 100`
2. Invoke hook → `max_iterations` becomes 110, `decision: "block"`
