# me plugin

Personal Claude Code workflow toolkit for git safety, verification, shipping, research, and development automation.

## SDLC stages

The chain follows the [AI-native SDLC](https://claude.com/blog/the-ai-native-sdlc-playbook):
each stage commits an artifact the next stage reads.

| Stage | Artifact | Skills |
| ----- | -------- | ------ |
| Plan / Design | `docs/specs/*.md` | `brainstorming` → `writing-spec` |
| Build | `docs/plans/*.md` + code | `writing-plans` → `subagent-driven-development`, `tdd` |
| Test | test results | `verify`, `e2e-scenario-testing`, `diagnosing-bugs` |
| Deploy | PR, release | `requesting-code-review`, `create-pr`, `ship` |
| Maintain | — | not yet implemented |

Each link is a hard gate on its input artifact: `writing-plans` needs a spec,
`subagent-driven-development` needs a plan. A spec's `## Open questions`
section carries what is still undecided; when it is empty, the next stage
proceeds without asking.

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
- `executing-plans` / `subagent-driven-development` — Execute plans with checkpoints and reviews.
- `tdd` — Build features and fix bugs test-first through the red-green loop.

### Verify

- `verify` — Verify implementation scope and report `PASS`, `PARTIAL`, or `FAIL` with evidence.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.
- `verification-before-completion` — Require fresh evidence before completion claims.
- `diagnosing-bugs` — Diagnose hard bugs by building a feedback loop that goes red before theorising.

### Review and completion

- `requesting-code-review` / `receiving-code-review` — Request and rigorously process code review.
- `finishing-a-development-branch` — Verify tests and choose how to integrate completed work.

### Ship

- `ship` — Run pre-deploy checks, the deploy, and post-deploy verification with a rollback path.
- `create-pr` — Commit, push, create a PR, and optionally wait for checks or merge.

### Session

- `write-skill` — Write or fix a `SKILL.md`, prove it against a no-skill baseline, and tune it with SkillOpt.

## Agents

- `researcher` — Gather current web documentation, best practices, and version-specific evidence.

## Hooks

- `WorktreeCreate` runs `hooks/setup-worktree.sh` through `bash`.
- `PreToolUse` for `Bash:git` runs `hooks/commit-guard.sh` to block unsafe git operations.

## References

Most detailed references live next to the skill that uses them, such as `skills/verify/references/`.

Selected workflow skills are mirrored from [obra/superpowers](https://github.com/obra/superpowers) at commit
`b36e0829c6d0140e93cfef2ca599b1b07d4a7797`. Upstream hooks and platform-specific plugin files are intentionally
excluded.
