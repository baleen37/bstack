# me plugin

Personal Claude Code workflow toolkit for git safety, session continuity, verification, shipping, and development automation.

## Lifecycle

### Define

- `to-prd` — Convert conversation context into a PRD and GitHub issue.
- `gh-to-issue` — Break a plan, spec, or PRD into independently grabbable GitHub issues.

### Plan

- `research` — Explore evidence before acting.
- `competitive-agents` — Compare parallel approaches for architecture, API, or system decisions.
- `documentation-and-adrs` — Capture decisions, public API changes, and future context.

### Build

- `setup` — Bootstrap global Claude Code configuration on a new machine.
- `git-workflow-and-versioning` — Manage branch, commit, conflict, and worktree workflows.
- `deprecation-and-migration` — Remove old systems and migrate users safely.

### Verify

- `qa` — Verify implementation scope and report `PASS`, `PARTIAL`, or `FAIL` with evidence.
- `verify` — Compose debugging and browser/runtime verification.
- `e2e` — Verify flows across multiple components, services, or layers.
- `browse` — Use browser automation for runtime and UI verification.
- `debugging-and-error-recovery` — Diagnose failing tests, builds, and unexpected behavior from first principles.

### Review

- `fix-pr` — Repair broken PRs, CI failures, conflicts, and test failures.

### Ship

- `ship` — Fan out launch review to specialist personas and synthesize a go/no-go decision.
- `shipping-and-launch` — Prepare staged rollout, monitoring, rollback, and production launch checks.
- `ci-cd-and-automation` — Design CI/CD pipelines, quality gates, and deployment automation.
- `create-pr` — Commit, push, create a PR, and optionally wait for checks or merge.

### Session

- `handoff` — Write structured session handoff files.
- `pickup` — Resume from a handoff and warn on branch or worktree mismatch.

## Agents

- `code-reviewer` — Review completed work against the original plan and coding standards.
- `security-auditor` — Audit production-bound changes for security launch risk.
- `test-engineer` — Review test coverage and verification evidence before shipping.
- `web-researcher` — Gather current web documentation, best practices, and version-specific evidence.

## Hooks

- `WorktreeCreate` runs `skills/setup/setup-worktree.sh` through `bash`.
- `PreToolUse` for `Bash:git` runs `hooks/commit-guard.sh` to block unsafe git operations.

## References

Most detailed references live next to the skill that uses them, such as `skills/browse/references/` and `skills/qa/references/`.
