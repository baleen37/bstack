# Ralph Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone `plugins/ralph/` plugin that ports OMC's Ralph Loop into bstack — a
PRD-driven persistence loop that intercepts Claude's `Stop` event to keep Claude working until all
user stories pass.

**Architecture:** A Bun TypeScript Stop hook script (`ralph-persist.ts`) reads state from
`.ralph/state/ralph-state.json` and returns `decision: "block"` to Claude Code to prevent stopping.
A SKILL.md instructs Claude to write a PRD, execute stories one by one, verify completion, then
create a cancel signal file to exit the loop.

**Tech Stack:** Bun (TypeScript runtime), Claude Code hooks API (Stop event), BATS (tests), JSON state files

**Spec:** `docs/superpowers/specs/2026-03-23-ralph-plugin-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `plugins/ralph/.claude-plugin/plugin.json` | Create | Plugin metadata (name, version, author, skills path) |
| `.claude-plugin/marketplace.json` | Modify | Register ralph plugin so marketplace tests pass |
| `plugins/ralph/hooks/hooks.json` | Create | Register Stop hook pointing to ralph-persist.ts |
| `plugins/ralph/hooks/ralph-persist.ts` | Create | Stop hook engine: read state, block or allow |
| `plugins/ralph/skills/ralph/SKILL.md` | Create | Claude protocol: PRD → stories → verify → cancel |
| `tests/ralph_persist.bats` | Create | Unit + flow tests for ralph-persist.ts |

---

## Task 1: Plugin scaffold + marketplace registration

**Files:**

- Create: `plugins/ralph/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create the plugin directory structure**

```bash
mkdir -p plugins/ralph/.claude-plugin
mkdir -p plugins/ralph/hooks
mkdir -p plugins/ralph/skills/ralph
```

- [ ] **Step 2: Verify marketplace test currently passes (baseline)**

```bash
bats tests/marketplace_json.bats
```

Expected: PASS — confirm baseline before adding ralph

- [ ] **Step 3: Create plugin.json**

```json
{
  "name": "ralph",
  "version": "1.0.0",
  "description": "PRD-driven persistence loop — keeps Claude working until all user stories pass",
  "author": {
    "name": "baleen37",
    "email": "git@baleen.me"
  },
  "license": "MIT",
  "keywords": ["ralph", "loop", "persistence", "prd", "automation"],
  "skills": "./skills/"
}
```

- [ ] **Step 4: Run plugin_json and marketplace tests — marketplace will fail**

```bash
bats tests/plugin_json.bats tests/marketplace_json.bats
```

Expected: `plugin_json.bats` PASS, `marketplace_json.bats` FAIL (ralph not listed)

- [ ] **Step 5: Add ralph to marketplace.json**

Add this entry to the `"plugins"` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "ralph",
  "description": "PRD-driven persistence loop — keeps Claude working until all user stories pass",
  "source": "./plugins/ralph",
  "category": "development",
  "tags": ["ralph", "loop", "persistence", "prd", "automation"],
  "version": "1.0.0"
}
```

- [ ] **Step 6: Run tests again — both must pass**

```bash
bats tests/plugin_json.bats tests/marketplace_json.bats
```

Expected: PASS (both)

- [ ] **Step 7: Commit**

```bash
git add plugins/ralph/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "feat(ralph): scaffold plugin with plugin.json and marketplace registration"
```

---

## Task 2: hooks.json

**Files:**

- Create: `plugins/ralph/hooks/hooks.json`

- [ ] **Step 1: Write the failing test**

The existing `tests/hooks_json.bats` only validates `plugins/me/hooks/hooks.json`. Create a new test file:

```bash
cat > tests/ralph_hooks_json.bats << 'EOF'
#!/usr/bin/env bats
# Test: ralph plugin hooks.json validation

load helpers/bats_helper

HOOKS_JSON="${PROJECT_ROOT}/plugins/ralph/hooks/hooks.json"

setup() {
    ensure_jq
}

@test "ralph hooks.json is valid JSON" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"
    validate_json "$HOOKS_JSON"
}

@test "ralph hooks.json has Stop hook" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"
    local has_stop
    has_stop=$($JQ_BIN -e '.hooks.Stop' "$HOOKS_JSON")
    [ -n "$has_stop" ]
}

@test "ralph hooks.json Stop hook uses CLAUDE_PLUGIN_ROOT" {
    [ -f "$HOOKS_JSON" ] || skip "hooks.json not found"
    local command
    command=$($JQ_BIN -r '.hooks.Stop[0].hooks[0].command' "$HOOKS_JSON")
    [[ "$command" == *'${CLAUDE_PLUGIN_ROOT}'* ]]
}
EOF
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bats tests/ralph_hooks_json.bats
```

Expected: SKIP (hooks.json not found)

- [ ] **Step 3: Create hooks.json**

```json
{
  "description": "Ralph Loop hooks",
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bun run \"${CLAUDE_PLUGIN_ROOT}/hooks/ralph-persist.ts\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/ralph_hooks_json.bats
```

Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add plugins/ralph/hooks/hooks.json tests/ralph_hooks_json.bats
git commit -m "feat(ralph): add Stop hook registration and tests"
```

---

## Task 3: ralph-persist.ts — pass-through cases

**Files:**

- Create: `plugins/ralph/hooks/ralph-persist.ts`
- Create: `tests/ralph_persist.bats`

- [ ] **Step 1: Write failing tests for all pass-through conditions**

```bash
cat > tests/ralph_persist.bats << 'EOF'
#!/usr/bin/env bats
# Test: ralph-persist.ts Stop hook engine

load helpers/bats_helper

HOOK_SCRIPT="${PROJECT_ROOT}/plugins/ralph/hooks/ralph-persist.ts"
RALPH_DIR=""

setup() {
    RALPH_DIR="$(mktemp -d)/project"
    mkdir -p "${RALPH_DIR}/.ralph/state"
}

teardown() {
    rm -rf "$(dirname "$RALPH_DIR")"
}

# Helper: invoke the hook with given session_id and cwd
invoke_hook() {
    local session_id="${1:-test-session}"
    local cwd="${2:-$RALPH_DIR}"
    echo "{\"session_id\": \"$session_id\", \"cwd\": \"$cwd\", \"hook_event_name\": \"Stop\"}" \
        | bun run "$HOOK_SCRIPT"
}

# Helper: write state file
write_state() {
    local state="$1"
    echo "$state" > "${RALPH_DIR}/.ralph/state/ralph-state.json"
}

@test "no state file: writes nothing and exits 0" {
    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "active false: writes nothing and exits 0" {
    write_state '{"active":false,"session_id":"test-session","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z"}'
    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "session_id mismatch: writes nothing and exits 0" {
    write_state '{"active":true,"session_id":"session-A","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z"}'
    run invoke_hook "session-B"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "cancel signal exists: writes nothing, deletes signal, sets active false" {
    write_state '{"active":true,"session_id":"test-session","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z"}'
    touch "${RALPH_DIR}/.ralph/state/cancel-signal-state.json"

    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f "${RALPH_DIR}/.ralph/state/cancel-signal-state.json" ]
    local active
    active=$($JQ_BIN -r '.active' "${RALPH_DIR}/.ralph/state/ralph-state.json")
    [ "$active" = "false" ]
}

@test "stale state (>2h): writes nothing, sets active false" {
    local stale_time
    stale_time=$(date -u -v-3H '+%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null || date -u -d '3 hours ago' '+%Y-%m-%dT%H:%M:%S.000Z')
    write_state "{\"active\":true,\"session_id\":\"test-session\",\"iteration\":1,\"max_iterations\":100,\"last_checked_at\":\"$stale_time\"}"

    run invoke_hook
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    local active
    active=$($JQ_BIN -r '.active' "${RALPH_DIR}/.ralph/state/ralph-state.json")
    [ "$active" = "false" ]
}
EOF
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bats tests/ralph_persist.bats
```

Expected: FAIL (hook script not found)

- [ ] **Step 3: Implement ralph-persist.ts — pass-through cases only**

```typescript
#!/usr/bin/env bun
import { existsSync, readFileSync, writeFileSync, unlinkSync, mkdirSync } from "fs";
import { join } from "path";

const STALE_THRESHOLD_MS = 2 * 60 * 60 * 1000; // 2 hours

interface HookInput {
  session_id?: string;
  cwd?: string;
  hook_event_name?: string;
}

interface RalphState {
  active: boolean;
  session_id: string;
  iteration: number;
  max_iterations: number;
  started_at: string;
  last_checked_at: string;
  prompt: string;
}

function readState(stateDir: string): RalphState | null {
  const path = join(stateDir, "ralph-state.json");
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, "utf8")) as RalphState;
  } catch {
    return null;
  }
}

function writeState(stateDir: string, state: RalphState): void {
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, "ralph-state.json"), JSON.stringify(state, null, 2));
}

function allow(): void {
  // Write nothing, exit 0
  process.exit(0);
}

function block(iteration: number, maxIterations: number, prompt: string): void {
  process.stdout.write(
    JSON.stringify({
      decision: "block",
      reason: `[RALPH LOOP - ITERATION ${iteration}/${maxIterations}] Work is not done. Continue working on the task: ${prompt}`,
    })
  );
  process.exit(0);
}

async function main(): Promise<void> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk as Buffer);
  }
  const input: HookInput = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");

  const cwd = input.cwd ?? process.cwd();
  const sessionId = input.session_id ?? "";
  const stateDir = join(cwd, ".ralph", "state");

  // Check activation sentinel
  const activatingSentinel = join(stateDir, "ralph-activating");
  if (existsSync(activatingSentinel) && !existsSync(join(stateDir, "ralph-state.json"))) {
    const prompt = readFileSync(activatingSentinel, "utf8").trim();
    unlinkSync(activatingSentinel);
    const now = new Date().toISOString();
    const state: RalphState = {
      active: true,
      session_id: sessionId,
      iteration: 0,
      max_iterations: 100,
      started_at: now,
      last_checked_at: now,
      prompt,
    };
    writeState(stateDir, state);
    block(1, state.max_iterations, state.prompt);
    return;
  }

  const state = readState(stateDir);

  // Pass-through: no state
  if (!state) {
    allow();
    return;
  }

  // Pass-through: inactive
  if (!state.active) {
    allow();
    return;
  }

  // Pass-through: session mismatch
  if (state.session_id && sessionId && state.session_id !== sessionId) {
    allow();
    return;
  }

  // Pass-through: cancel signal
  const cancelSignal = join(stateDir, "cancel-signal-state.json");
  if (existsSync(cancelSignal)) {
    unlinkSync(cancelSignal);
    state.active = false;
    writeState(stateDir, state);
    allow();
    return;
  }

  // Pass-through: stale state
  const lastChecked = new Date(state.last_checked_at).getTime();
  if (Date.now() - lastChecked > STALE_THRESHOLD_MS) {
    state.active = false;
    writeState(stateDir, state);
    allow();
    return;
  }

  // Block: extend max_iterations if needed, then block
  if (state.iteration >= state.max_iterations) {
    state.max_iterations += 10;
  }
  state.iteration += 1;
  state.last_checked_at = new Date().toISOString();
  writeState(stateDir, state);
  block(state.iteration, state.max_iterations, state.prompt);
}

main().catch((err) => {
  process.stderr.write(`ralph-persist error: ${err}\n`);
  process.exit(0); // Always exit 0 — never crash Claude
});
```

- [ ] **Step 4: Run pass-through tests**

```bash
bats tests/ralph_persist.bats
```

Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add plugins/ralph/hooks/ralph-persist.ts tests/ralph_persist.bats
git commit -m "feat(ralph): implement Stop hook pass-through logic"
```

---

## Task 4: ralph-persist.ts — block logic tests

**Files:**

- Modify: `tests/ralph_persist.bats`

- [ ] **Step 1: Add block logic tests**

Append to `tests/ralph_persist.bats`:

```bash
@test "active state with matching session: returns decision block and increments iteration" {
    write_state '{"active":true,"session_id":"test-session","iteration":2,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z","prompt":"build todo API"}'

    run invoke_hook "test-session"
    [ "$status" -eq 0 ]
    local decision
    decision=$($JQ_BIN -r '.decision' <<< "$output")
    [ "$decision" = "block" ]
    local iteration
    iteration=$($JQ_BIN -r '.iteration' "${RALPH_DIR}/.ralph/state/ralph-state.json")
    [ "$iteration" = "3" ]
}

@test "max_iterations reached: extends by 10 and blocks" {
    write_state '{"active":true,"session_id":"test-session","iteration":100,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z","prompt":"build todo API"}'

    run invoke_hook "test-session"
    [ "$status" -eq 0 ]
    local decision
    decision=$($JQ_BIN -r '.decision' <<< "$output")
    [ "$decision" = "block" ]
    local max_iter
    max_iter=$($JQ_BIN -r '.max_iterations' "${RALPH_DIR}/.ralph/state/ralph-state.json")
    [ "$max_iter" = "110" ]
}
```

- [ ] **Step 2: Run tests**

```bash
bats tests/ralph_persist.bats
```

Expected: PASS (7 tests)

- [ ] **Step 3: Commit**

```bash
git add tests/ralph_persist.bats
git commit -m "test(ralph): add block logic and max_iterations tests"
```

---

## Task 5: Flow integration tests

**Files:**

- Modify: `tests/ralph_persist.bats`

- [ ] **Step 1: Add flow tests**

Append to `tests/ralph_persist.bats`:

```bash
@test "happy path: full loop lifecycle" {
    # Setup: active state
    write_state '{"active":true,"session_id":"test-session","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z","prompt":"build todo API"}'

    # iteration 1 → block, becomes 2
    run invoke_hook "test-session"
    [ "$status" -eq 0 ]
    local decision
    decision=$($JQ_BIN -r '.decision' <<< "$output")
    [ "$decision" = "block" ]

    # iteration 2 → block, becomes 3
    run invoke_hook "test-session"
    [ "$status" -eq 0 ]
    decision=$($JQ_BIN -r '.decision' <<< "$output")
    [ "$decision" = "block" ]

    # Create cancel signal
    touch "${RALPH_DIR}/.ralph/state/cancel-signal-state.json"

    # Next stop → allow, cancel signal deleted, active false
    run invoke_hook "test-session"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f "${RALPH_DIR}/.ralph/state/cancel-signal-state.json" ]
    local active
    active=$($JQ_BIN -r '.active' "${RALPH_DIR}/.ralph/state/ralph-state.json")
    [ "$active" = "false" ]
}

@test "session isolation: orphaned state is ignored" {
    write_state '{"active":true,"session_id":"session-A","iteration":1,"max_iterations":100,"last_checked_at":"2099-01-01T00:00:00.000Z","prompt":"build todo API"}'

    run invoke_hook "session-B"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "activation sentinel: creates state and blocks on first stop" {
    mkdir -p "${RALPH_DIR}/.ralph/state"
    echo "build todo API" > "${RALPH_DIR}/.ralph/state/ralph-activating"

    run invoke_hook "test-session"
    [ "$status" -eq 0 ]
    local decision
    decision=$($JQ_BIN -r '.decision' <<< "$output")
    [ "$decision" = "block" ]
    [ -f "${RALPH_DIR}/.ralph/state/ralph-state.json" ]
    [ ! -f "${RALPH_DIR}/.ralph/state/ralph-activating" ]
}
```

- [ ] **Step 2: Run all tests**

```bash
bats tests/ralph_persist.bats
```

Expected: PASS (10 tests)

- [ ] **Step 3: Commit**

```bash
git add tests/ralph_persist.bats
git commit -m "test(ralph): add flow integration tests"
```

---

## Task 6: SKILL.md

**Files:**

- Create: `plugins/ralph/skills/ralph/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

```markdown
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

   ```text
   [ITERATION N] Story US-XXX failed: <what went wrong> / <what to try next>
   ```

## Completion Verification

When all stories have `passes: true`:

1. **Architect review** (skip with `--critic=none`): Review the full implementation for design quality,
   edge cases, and code clarity. Fix any issues found.
2. **Deslop pass** (skip with `--no-deslop`): Remove AI-generated boilerplate, overly verbose comments,
   unnecessary abstractions, and any code that exists for no clear reason.
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

- [ ] **Step 2: Verify frontmatter test passes**

```bash
bats tests/frontmatter_tests.bats
```

Expected: PASS

- [ ] **Step 3: Run all tests**

```bash
bats tests/
```

Expected: PASS (all tests)

- [ ] **Step 4: Commit**

```bash
git add plugins/ralph/skills/ralph/SKILL.md
git commit -m "feat(ralph): add ralph skill with PRD-driven loop protocol"
```

---

## Task 7: Final validation

- [ ] **Step 1: Run full test suite**

```bash
bats tests/
```

Expected: PASS (all tests including new ralph tests)

- [ ] **Step 2: Run pre-commit hooks**

```bash
pre-commit run --all-files
```

Expected: PASS

- [ ] **Step 3: Verify plugin structure**

```bash
find plugins/ralph -type f | sort
```

Expected output:

```text
plugins/ralph/.claude-plugin/plugin.json
plugins/ralph/hooks/hooks.json
plugins/ralph/hooks/ralph-persist.ts
plugins/ralph/skills/ralph/SKILL.md
```

- [ ] **Step 4: Commit if any fixes needed, then final commit**

```bash
git add -p
git commit -m "chore(ralph): final validation and cleanup"
```
