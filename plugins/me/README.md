# me plugin

Personal Claude Code and Codex workflow toolkit for git safety, verification, shipping, research, and development automation.

## SDLC stages

The chain follows the [AI-native SDLC](https://claude.com/blog/the-ai-native-sdlc-playbook):
each stage commits an artifact the next stage reads.

| Stage | Artifact | Skills |
| ----- | -------- | ------ |
| Plan / Design | `docs/specs/*.md` | `brainstorming` → `writing-spec` |
| Build | `docs/plans/*.md` + code | `writing-plans` → `executing-plans` or `subagent-driven-development`, `tdd` |
| Test | test results | `verify`, `e2e-scenario-testing`, `diagnosing-bugs` |
| Deploy | PR, release | `code-review`, `requesting-code-review`, `create-pr`, `ship` |
| Maintain | — | not yet implemented |

Each link is a hard gate on its input artifact: `writing-plans` needs a spec,
`subagent-driven-development` needs a plan. A spec's `## Open questions`
section carries what is still undecided; when it is empty, the next stage
proceeds without asking.

## Start here

- `ask` — Router over these skills: which one fits the situation, and where the
  phase boundaries fall. User-invoked (`/me:ask`).

## Lifecycle

### Plan

- `research` — Investigate questions against primary sources and save cited findings.
- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.

### Development workflow

- `brainstorming` — Explore intent and requirements before implementation.
- `writing-spec` — Write the approved design as a spec document.
- `writing-plans` — Create detailed, executable implementation plans.
- `using-git-worktrees` — Create or verify isolated workspaces.
- `dispatching-parallel-agents` — Run independent tasks in parallel.
- `executing-plans` / `subagent-driven-development` — Execute plans inline or with per-task implementers and reviews.
- `tdd` — Build features and fix bugs test-first through the red-green loop.

### Verify

- `verify` — Verify implementation scope and report `PASS`, `PARTIAL`, or `FAIL` with evidence.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.
- `verification-before-completion` — Require fresh evidence before completion claims.
- `diagnosing-bugs` — Diagnose hard bugs by building a feedback loop that goes red before theorising.

### Review and completion

- `code-review` — Review a range on two axes: Standards and Spec, in parallel subagents.
- `requesting-code-review` / `receiving-code-review` — Request and rigorously process code review.
- `finishing-a-development-branch` — Verify tests and choose how to integrate completed work.

### Ship

- `ship` — Run pre-deploy checks, the deploy, and post-deploy verification with a rollback path.
- `create-pr` — Commit, push, create a PR, and optionally wait for checks or merge.

### Session

- `handoff` — Hand this session's state to the next one, verifiable and resumable.
- `diagnosing-agent-sessions` — Explain a past or current agent session with transcript evidence and privacy gates.
- `write-skill` — Write or fix a `SKILL.md`, prove it against a no-skill baseline, and tune it with SkillOpt.

## Agents

- `researcher` — Gather current web documentation, best practices, and version-specific evidence.

## Hooks

- `WorktreeCreate` runs `hooks/setup-worktree.sh` through `bash`.
- `PreToolUse` for `Bash:git` runs `hooks/commit-guard.sh` to block unsafe git operations.

## References

Most detailed references live next to the skill that uses them, such as `skills/verify/references/`.

Selected workflow changes are adapted from [obra/superpowers v6.4.1](https://github.com/obra/superpowers/commit/5bf4e78011075bcfc0dc295f0724994cd123ee71).
They are adapted to `me` routing, `.bstack` workspaces, and Claude Code/Codex;
upstream hooks and platform-specific plugin files are intentionally excluded.
