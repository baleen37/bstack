# me plugin

Personal Claude Code workflow toolkit for git safety, session continuity, verification, shipping, and development automation.

## Lifecycle

### Plan

- `grill-with-docs` — Sharpen a plan or design through an interview while creating docs.
- `domain-modeling` — Build and sharpen the project's domain model.
- `grilling` — Relentlessly stress-test a plan, decision, or idea.
- `research` — Investigate questions against primary sources and save cited findings.
- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.
- `to-tickets` — Break a plan, spec, or conversation into tracer-bullet tickets with blocking edges.

### Verify

- `verify` — Verify implementation scope and report `PASS`, `PARTIAL`, or `FAIL` with evidence.
- `code-review` — Review a diff against repository standards and its originating specification.
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.
- `story-loop` — Inventory repository capabilities and loop through scenario testing, fixes, and fresh verification.

### Ship

- `ship` — Run pre-deploy checks, the deploy, and post-deploy verification with a rollback path.
- `create-pr` — Commit, push, create a PR, and optionally wait for checks or merge.

### Session

- `handoff` — Compact the current conversation into a handoff document for another agent.
- `write-skill` — Write or fix a `SKILL.md`, prove it against a no-skill baseline, and tune it with SkillOpt.

## Agents

- `code-reviewer` — Review completed work against the original plan and coding standards.
- `security-auditor` — Audit production-bound changes for security launch risk.
- `test-engineer` — Review test coverage and verification evidence before shipping.
- `researcher` — Gather current web documentation, best practices, and version-specific evidence.

## Hooks

- `WorktreeCreate` runs `hooks/setup-worktree.sh` through `bash`.
- `PreToolUse` for `Bash:git` runs `hooks/commit-guard.sh` to block unsafe git operations.

## References

Most detailed references live next to the skill that uses them, such as `skills/verify/references/`.
