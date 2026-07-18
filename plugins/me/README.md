# me plugin

Personal Claude Code workflow toolkit for git safety, session continuity, verification, shipping, and development automation.

## Lifecycle

### Plan

- `research` — Explore evidence before acting.
- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.

### Build

- `setup` — Bootstrap global Claude Code configuration on a new machine.

### Verify

- `test` — Design, run, and improve tests using local conventions and `test-engineer`.
- `qa` — Verify implementation scope and report `PASS`, `PARTIAL`, or `FAIL` with evidence.
- `e2e` — Verify flows across multiple components, services, or layers.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.
- `story-loop` — Inventory repository capabilities and loop through scenario testing, fixes, and fresh verification.

### Review

- `review` — Review code with specialist subagents for correctness, tests, security, and architecture.

### Ship

- `ship` — Prepare staged rollout, monitoring, rollback, and production launch checks.
- `create-pr` — Commit, push, create a PR, and optionally wait for checks or merge.

### Evolve

- `evolve` — Aggregate skill-usage signals and propose skill improvements.

### Session

- `handoff` — Write structured session handoff files.

## Agents

- `code-reviewer` — Review completed work against the original plan and coding standards.
- `security-auditor` — Audit production-bound changes for security launch risk.
- `test-engineer` — Review test coverage and verification evidence before shipping.
- `researcher` — Gather current web documentation, best practices, and version-specific evidence.

## Hooks

- `WorktreeCreate` runs `skills/setup/setup-worktree.sh` through `bash`.
- `PreToolUse` for `Bash:git` runs `hooks/commit-guard.sh` to block unsafe git operations.

## References

Most detailed references live next to the skill that uses them, such as `skills/qa/references/`.
