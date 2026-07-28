# tmux Agent Status Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a provider-neutral `me` plugin hook that writes Claude Code and Codex lifecycle state to the current tmux pane.

**Architecture:** One Bash hook consumes lifecycle JSON from stdin and writes a
fixed semantic value to the pane-local `@agent_status` option. A private
pane-local `@agent_status_session_id` option prevents an old session from
clearing a newer session's state. The shared plugin `hooks.json` registers only
events supported by both providers; UI rendering remains in dotfiles.

**Tech Stack:** Bash, jq, tmux, JSON, BATS

## Global Constraints

- Herdr, daemon, state files, network calls, and provider-specific hook events are forbidden.
- The shared pane option is exactly `@agent_status`; values are exactly `running`, `needs_input`, and `ready`.
- The private ownership option is exactly `@agent_status_session_id`; it does
  not change the cross-repo public state contract.
- Event mapping is exactly `SessionStart→ready`, `UserPromptSubmit→running`, `PermissionRequest→needs_input`, `Stop→ready`, `SessionEnd→unset`.
- Active events must set owner and status in one tmux command sequence.
- `SessionEnd` must unset status and owner in one tmux command sequence only
  when its `session_id` matches the current owner.
- Missing `TMUX_PANE`, missing tmux, missing or empty `session_id`, invalid JSON,
  unknown events, and tmux failures must exit 0 without output.
- Hook commands must use the exact portable root expression `${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}`.
- Existing `WorktreeCreate` and `PreToolUse` hooks must remain unchanged.
- Follow strict RED→GREEN TDD and do not edit version files.

---

### Task 1: Add the shared tmux lifecycle hook

**Files:**
- Create: `tests/me/agent-status.bats`
- Create: `plugins/me/hooks/agent-status.sh`
- Modify: `plugins/me/hooks/hooks.json`

**Interfaces:**
- Consumes: lifecycle JSON on stdin, `TMUX_PANE`, `jq`, and `tmux`.
- Produces: pane-local `@agent_status` with the contract in Global Constraints.

- [ ] **Step 1: Write the failing behavioral tests**

Create `tests/me/agent-status.bats`. Load `../helpers/bats_helper`, create a
temporary fake `tmux` executable that appends all arguments to `$TMUX_LOG`, and
invoke the real hook with JSON such as
`{"hook_event_name":"UserPromptSubmit","session_id":"session-1"}`.

The tests must assert these literal observable effects:

```text
SessionStart       -> set owner=session-1 ; set status=ready
UserPromptSubmit   -> set owner=session-1 ; set status=running
PermissionRequest -> set owner=session-1 ; set status=needs_input
Stop               -> set owner=session-1 ; set status=ready
SessionEnd         -> when owner matches, unset status ; unset owner
```

Each successful state change must also log `refresh-client -S`. Add separate
tests proving:

```bash
env -u TMUX_PANE "$HOOK"
PATH="$TEST_TEMP_DIR/no-tmux" TMUX_PANE="%7" /bin/bash "$HOOK"
printf '%s\n' 'not-json' | TMUX_PANE="%7" "$HOOK"
printf '%s\n' '{"hook_event_name":"Other"}' | TMUX_PANE="%7" "$HOOK"
```

all exit 0 and do not invoke tmux. Replace the fake tmux with an executable
that exits 1 and prove a known event still exits 0.

Add a stateful regression proving `A SessionStart`, `B UserPromptSubmit`,
`A SessionEnd` leaves B's owner and `running` state intact, then
`B SessionEnd` unsets both options. Also prove missing and empty `session_id`
are successful no-ops.

Finally parse `plugins/me/hooks/hooks.json` with jq and assert all five event
entries have matcher `*`, the four active events have timeout `5`,
`SessionEnd` has timeout `3`, and every command is exactly:

```text
"${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/hooks/agent-status.sh"
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
PATH=/opt/homebrew/bin:$PATH bats tests/me/agent-status.bats
```

Expected: FAIL because `plugins/me/hooks/agent-status.sh` and the five hook
registrations do not exist. Confirm the failure is caused by the missing
feature.

- [ ] **Step 3: Implement the minimal hook**

Create executable `plugins/me/hooks/agent-status.sh` with this control flow:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${TMUX_PANE:-}" ]] || ! command -v tmux >/dev/null 2>&1; then
    exit 0
fi

payload="$(
    jq -r '
        if (.hook_event_name | type) == "string" and (.session_id | type) == "string" then
            [.hook_event_name, .session_id] | @tsv
        else
            empty
        end
    ' 2>/dev/null
)" || exit 0
[[ -n "$payload" ]] || exit 0

IFS=$'\t' read -r event session_id <<< "$payload"
[[ -n "$event" && -n "$session_id" ]] || exit 0

case "$event" in
    SessionStart | Stop)
        state="ready"
        ;;
    UserPromptSubmit)
        state="running"
        ;;
    PermissionRequest)
        state="needs_input"
        ;;
    SessionEnd)
        current_session_id="$(
            tmux show-option -pv -t "$TMUX_PANE" @agent_status_session_id 2>/dev/null
        )" || exit 0
        [[ "$current_session_id" == "$session_id" ]] || exit 0

        tmux set-option -pu -t "$TMUX_PANE" @agent_status \; \
            set-option -pu -t "$TMUX_PANE" @agent_status_session_id \
            >/dev/null 2>&1 || true
        tmux refresh-client -S >/dev/null 2>&1 || true
        exit 0
        ;;
    *)
        exit 0
        ;;
esac

tmux set-option -p -t "$TMUX_PANE" @agent_status_session_id "$session_id" \; \
    set-option -p -t "$TMUX_PANE" @agent_status "$state" \
    >/dev/null 2>&1 || true
tmux refresh-client -S >/dev/null 2>&1 || true
```

Make the file executable. Add the five event arrays to
`plugins/me/hooks/hooks.json`, each using matcher `*`, a command hook with the
exact portable path from Step 1, timeout `5` for active events, and timeout `3`
for `SessionEnd`. Preserve the existing hook objects byte-for-byte except for
JSON formatting required to insert siblings.

- [ ] **Step 4: Run focused verification and verify GREEN**

Run:

```bash
PATH=/opt/homebrew/bin:$PATH bats tests/me/agent-status.bats
PATH=/opt/homebrew/bin:$PATH bats tests/hooks_json.bats
shellcheck plugins/me/hooks/agent-status.sh
jq empty plugins/me/hooks/hooks.json
bun run check:codex
```

Expected: all commands exit 0 with no warnings.

- [ ] **Step 5: Run the full suite**

Run:

```bash
PATH=/opt/homebrew/bin:$PATH bash tests/run-all-tests.sh
pre-commit run --all-files
```

Expected: all tests and hooks pass.

- [ ] **Step 6: Commit**

```bash
git add tests/me/agent-status.bats plugins/me/hooks/agent-status.sh plugins/me/hooks/hooks.json
git commit -m "feat(me): add tmux agent status hooks"
```
