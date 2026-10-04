# core plugin

Install `core` for the complete Claude Code and Codex development workflow.
It contains 38 skills: planning, TDD and debugging, verification,
review, PR creation, deployment, and independent engineering tools.

## Default workflow

`core:writing-plans` → `core:executing-plans` or
`core:subagent-driven-development` → `core:verify` → `core:code-review` → `core:create-pr`.

Small changes can be implemented directly. Multi-step work starts with a reviewed
plan; use `writing-spec` when a durable design artifact is useful. Direct and
subagent execution depend on the work, available tools, and the user's choice.
General development requires no tracker configuration.

| Stage | Artifact | Skills |
| --- | --- | --- |
| Design | `docs/specs/*.md` when a durable design artifact is useful | `domain-modeling`, `writing-spec` |
| Plan and build | `docs/plans/*.md`, code, execution ledger | `writing-plans`, `executing-plans` or `subagent-driven-development`, `tdd` |
| Verify | real behavior and test evidence | `verify`, `e2e-scenario-testing`, `diagnosing-bugs`, `verification-before-completion` |
| Review | findings and feedback | `code-review` does the review; `requesting-code-review` arranges it; `receiving-code-review` handles feedback; `simplify` applies quality cleanups |
| Deliver | PR; requested release/deployment | `create-pr` includes [PR writing](skills/create-pr/references/pr-writing.md); `ship` handles deployment; `finishing-a-development-branch` handles branch completion |

## Optional routes

| Need | Route |
| --- | --- |
| Open design questions | `research` or `prototype` → `writing-spec` → written-spec review → `writing-plans` → selected executor |
| Tracker tickets | Explicitly invoke `to-tickets`; publish the plan's slices and dependencies without a separate execution graph |
| Tracker configuration | `setup` configures tracker-backed features and domain-doc conventions; local specs need no setup |
| Session continuity | `handoff` carries context; `retro` improves the environment; `diagnosing-workflow` investigates failed sessions |
| Evidence before a decision | `research`, `prototype`, `competitive-agents`, `writing-rfcs` |

`writing-spec` captures design decisions in
`docs/specs/YYYY-MM-DD-<topic>-design.md`. Publishing to a tracker is an explicit
choice; the implementation plan remains the execution authority.

## Independent and supporting skills

| Area | Skills |
| --- | --- |
| Codebase vocabulary and upkeep | `codebase-design`, `improve-codebase-architecture`, `writing-for-agents` |
| Communication and incoming work | `triage`, `to-questionnaire`, `wait-what` |
| Learning and interfaces | `learn` (workspace: `~/.skills/learn/<topic>/`), `browser`, `wizard` |
| Execution support | `using-core`, `using-git-worktrees`, `dispatching-parallel-agents` |

## Agents and hooks

`researcher` gathers current documentation and version-specific evidence.
Existing hooks remain in place: `WorktreeCreate` sets up the worktree,
`PreToolUse` protects git operations, and agent-status hooks handle session,
prompt, permission, stop, and end events. They use the shared `hooks/` assets.

## Migration and provenance

See the root [installation migration](../../README.md#migrating-an-existing-installation)
to remove the old `superpower`, `mattpocock-skills`, and `me` packages and install
`core`. Historical plans and designs keep their
original names. [Upstream snapshots and MIT notices](upstream/README.md) are
preserved separately from the live workflow.
