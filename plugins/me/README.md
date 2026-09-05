# me plugin

Personal Claude Code workflow toolkit for git safety, verification, shipping, research, and development automation.

## Lifecycle

### Plan

- `research` — Investigate questions against primary sources and save cited findings.
- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.

### Verify

- `verify` — Verify implementation scope and report `PASS`, `PARTIAL`, or `FAIL` with evidence.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.

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
