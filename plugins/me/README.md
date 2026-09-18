# me plugin

Personal Claude Code workflow toolkit for git safety, verification, shipping, research, and development automation.

## Lifecycle

### Plan

- `research` — Investigate questions against primary sources and save cited findings.
- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.

### Development workflow

- `brainstorming` — Explore intent and requirements before implementation.
- `writing-plans` — Create detailed, executable implementation plans.
- `using-git-worktrees` — Create or verify isolated workspaces.
- `dispatching-parallel-agents` — Run independent tasks in parallel.
- `executing-plans` / `subagent-driven-development` — Execute plans with checkpoints and reviews.

### Verify

- `verify` — Verify implementation scope and report `PASS`, `PARTIAL`, or `FAIL` with evidence.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.
- `verification-before-completion` — Require fresh evidence before completion claims.

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
