# me plugin

Personal Claude Code and Codex workflow toolkit for git safety, verification, shipping, research, and development automation.

## SDLC stages

The chain follows the [AI-native SDLC](https://claude.com/blog/the-ai-native-sdlc-playbook):
each stage commits an artifact the next stage reads.

| Stage | Artifact | Skills |
| ----- | -------- | ------ |
| Plan / Design | `docs/specs/*.md` | Small: `superpower:brainstorming`; large: `wayfinder` → `superpower:brainstorming` |
| Build | `docs/plans/*.md` + code | `superpower:writing-plans` → `superpower:executing-plans` or `superpower:subagent-driven-development`, `tdd` |
| Test | test results | `verify`, `e2e-scenario-testing`, `me:diagnosing-bugs` |
| Deploy | PR, release | `code-review`, `simplify`, `superpower:requesting-code-review`, `create-pr`, `ship` |
| Maintain | — | not yet implemented |

The design-to-branch workflow skills live in the `superpower` plugin.
Wayfinder is for work too large for one session; it resolves decisions, then
hands a spec destination to `superpower:brainstorming` to write and review the
`docs/specs/*.md` document. A spec held for review stays at that gate; new
decisions return to the map. Small work stays in the main flow without a
Wayfinder map.

## Start here

- `ask` — Router over these skills: which one fits the situation, and where the
  phase boundaries fall. User-invoked (`/me:ask`).

## Lifecycle

### Plan

- `research` — Investigate questions against primary sources and save cited findings.
- `wayfinder` — Resolve decisions for work too large for one session; spec destinations continue to `superpower:brainstorming`.
- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.

### Development workflow

- `tdd` — Build features and fix bugs test-first through the red-green loop.

### Verify

- `verify` — Run the change end-to-end at its real surface and report `PASS`, `FAIL`, `BLOCKED`, or `SKIP` with evidence.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.
- `diagnosing-bugs` — Diagnose hard bugs by building a feedback loop that goes red before theorising.

### Review and completion

- `code-review` — Review a diff or PR for bugs and cleanups at an effort level, with optional `--fix` / `--comment`.
- `simplify` — Clean up the changed code for reuse, simplification, efficiency, and altitude, then apply the fixes.

### Ship

- `ship` — Run pre-deploy checks, the deploy, and post-deploy verification with a rollback path.
- `create-pr` — Commit, push, create a PR, and optionally wait for checks or merge.

### Session

- `handoff` — Hand this session's state to the next one, verifiable and resumable.
- `diagnosing-agent-sessions` — Explain a past or current agent session with transcript evidence and privacy gates.

## Agents

- `researcher` — Gather current web documentation, best practices, and version-specific evidence.

## Hooks

- `WorktreeCreate` runs `hooks/setup-worktree.sh` through `bash`.
- `PreToolUse` for `Bash:git` runs `hooks/commit-guard.sh` to block unsafe git operations.

## References

Most detailed references live next to the skill that uses them, such as `skills/verify/examples/`.

Selected workflow changes are adapted from an upstream workflow release (v6.4.1).
They are adapted to `me` routing, `.bstack` workspaces, and Claude Code/Codex;
upstream hooks and platform-specific plugin files are intentionally excluded.
