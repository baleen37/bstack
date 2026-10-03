# me plugin

Install `me` for the complete Claude Code and Codex development workflow.
It contains 41 skills: design and planning, TDD and debugging, verification,
review, PR creation, deployment, and independent engineering tools.

## Default workflow

`me:brainstorming` → `me:writing-plans` → `me:executing-plans` or
`me:subagent-driven-development` → `me:verify` → `me:code-review` → `me:create-pr`.

Brainstorming uses [grilling questions](skills/brainstorming/references/grilling.md)
and `me:domain-modeling` to establish intent and precise domain terms. Small
bounded changes use a short approved design and direct implementation; multi-step
work uses a written spec and plan. Direct and subagent execution depend on the
work, available tools, and the user's choice. General development requires no
tracker configuration.

| Stage | Artifact | Skills |
| --- | --- | --- |
| Design | approved design; `docs/specs/*.md` for architectural work | `brainstorming`, `domain-modeling` |
| Plan and build | `docs/plans/*.md`, code, execution ledger | `writing-plans`, `executing-plans` or `subagent-driven-development`, `tdd` |
| Verify | real behavior and test evidence | `verify`, `e2e-scenario-testing`, `diagnosing-bugs`, `verification-before-completion` |
| Review | findings and feedback | `code-review` does the review; `requesting-code-review` arranges it; `receiving-code-review` handles feedback; `simplify` applies quality cleanups |
| Deliver | PR; requested release/deployment | `create-pr` includes [PR writing](skills/create-pr/references/pr-writing.md); `ship` handles deployment; `finishing-a-development-branch` handles branch completion |

## Optional routes

| Need | Route |
| --- | --- |
| Large unresolved uncertainty | `wayfinder` → `writing-spec` → written-spec review → `writing-plans` → selected executor |
| Tracker tickets | Explicitly invoke `to-tickets`; publish the plan's slices and dependencies without a separate execution graph |
| Tracker configuration | `setup` configures tracker-backed features and domain-doc conventions; local specs need no setup |
| Session continuity | `ask` routes to a flow; `handoff` carries context; `retro` improves the environment; `diagnosing-workflow` investigates failed sessions |
| Evidence before a decision | `research`, `prototype`, `competitive-agents`, `writing-rfcs` |

`writing-spec` synthesizes the conversation or resolved map to
`docs/specs/YYYY-MM-DD-<topic>-design.md`. Publishing to a tracker is an explicit
choice. Wayfinder decision tickets resolve uncertainty; the implementation plan
remains the execution authority.

## Independent and supporting skills

| Area | Skills |
| --- | --- |
| Codebase vocabulary and upkeep | `codebase-design`, `improve-codebase-architecture`, `writing-for-agents` |
| Communication and incoming work | `triage`, `to-questionnaire`, `wait-what` |
| Learning and interfaces | `learn` (workspace: `~/.skills/learn/<topic>/`), `browser`, `wizard` |
| Execution support | `using-me`, `using-git-worktrees`, `dispatching-parallel-agents` |

## Agents and hooks

`researcher` gathers current documentation and version-specific evidence.
Existing hooks remain in place: `WorktreeCreate` sets up the worktree,
`PreToolUse` protects git operations, and agent-status hooks handle session,
prompt, permission, stop, and end events. They use the shared `hooks/` assets.

## Migration and provenance

See the root [installation migration](../../README.md#설치-전환) to remove the
two old packages and update `me`. Historical plans and designs keep their
original names. [Upstream snapshots and MIT notices](upstream/README.md) are
preserved separately from the live workflow.
