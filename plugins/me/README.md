# me plugin

Personal Claude Code and Codex workflow toolkit for git safety, verification, shipping, research, and development automation.

## SDLC stages

The chain follows the [AI-native SDLC](https://claude.com/blog/the-ai-native-sdlc-playbook):
each stage commits an artifact the next stage reads. `me` holds the bstack-specific
skills; the design-to-branch workflow lives in `superpower`, and Matt Pocock's
skills live in `mattpocock-skills`.

| Stage | Artifact | Skills |
| ----- | -------- | ------ |
| Plan / Design | `docs/specs/*.md` | `superpower:brainstorming`; large work: `mattpocock-skills:wayfinder` first |
| Build | `docs/plans/*.md` + code | `superpower:writing-plans` → `superpower:executing-plans` or `superpower:subagent-driven-development`, `mattpocock-skills:tdd` |
| Test | test results | `verify`, `e2e-scenario-testing`, `mattpocock-skills:diagnosing-bugs` |
| Deploy | PR, release | `mattpocock-skills:code-review`, `simplify`, `create-pr`, `ship` |
| Maintain | — | not yet implemented |

## Lifecycle

### Plan

- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.

### Verify

- `verify` — Run the change end-to-end at its real surface and report `PASS`, `FAIL`, `BLOCKED`, or `SKIP` with evidence.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.

### Review

- `simplify` — Clean up the changed code for reuse, simplification, efficiency, and altitude, then apply the fixes.

### Ship

- `ship` — Run pre-deploy checks, the deploy, and post-deploy verification with a rollback path.
- `create-pr` — Commit, push, create a PR, and optionally wait for checks or merge.

### Session

- `diagnosing-agent-sessions` — Explain a past or current agent session with transcript evidence and privacy gates.
- `learn` — Learn a concept over several sessions in a stateful workspace.

### Other

- `browser` — Browser automation, including logged-in accounts and open tabs.

## Agents

- `researcher` — Gather current web documentation, best practices, and version-specific evidence.

## Hooks

- `WorktreeCreate` runs `hooks/setup-worktree.sh` through `bash`.
- `PreToolUse` for `Bash:git` runs `hooks/commit-guard.sh` to block unsafe git operations.

## References

Most detailed references live next to the skill that uses them, such as `skills/verify/examples/`.
