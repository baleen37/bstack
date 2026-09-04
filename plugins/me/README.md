# me plugin

Personal Claude Code workflow toolkit for git safety, session continuity, verification, shipping, and development automation.

## Lifecycle

### Plan

- `grill-with-docs` — Sharpen a plan or design through an interview while creating docs.
- `domain-modeling` — Build and sharpen the project's domain model.
- `grilling` — Relentlessly stress-test a plan, decision, or idea.
- `research` — Investigate questions against primary sources and save cited findings.
- `prototype` — Build throwaway prototypes to answer UI or state-model questions.
- `wayfinder` — Map huge, multi-session efforts as decision tickets.
- `writing-prds` — Write product requirements documents for feature planning.
- `writing-rfcs` — Write technical RFCs for engineering decisions.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.
- `codebase-design` — Design deep modules with small interfaces, clean seams, and testable adapters.
- `to-spec` — Turn the current conversation into a spec and publish it to the project tracker.
- `to-tickets` — Break a plan, spec, or conversation into tracer-bullet tickets with blocking edges.
- `implement` — Implement work described by a spec or set of tickets.
- `tdd` — Build features or fixes with a red-green-refactor loop.

### Maintain

- `diagnosing-bugs` — Diagnose hard bugs and performance regressions with a tight feedback loop.
- `improve-codebase-architecture` — Find codebase deepening opportunities and present them as an HTML report.
- `resolving-merge-conflicts` — Resolve merge or rebase conflicts by tracing each side's intent.

### Intake and Operations

- `triage` — Move incoming issues through a triage state machine.
- `wizard` — Guide human-only infrastructure, credential, and one-off migration steps.

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
- `writing-for-agents` — Write skills, agent instructions, and other documents agents consume.

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
