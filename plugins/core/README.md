# core plugin

Install `core` for the complete Claude Code and Codex development workflow.
It contains 34 skills built on Matt Pocock's engineering flow, plus local
verification, review, PR, and shipping tools.

## Default workflow

`core:grill-with-docs` → `core:to-spec` → `core:to-tickets` → `core:implement`
(per ticket) or `core:implement-spec` (whole spec) → `core:verify` → `core:code-review` → `core:create-pr`.

Small changes skip the spec: `core:implement` runs directly in the current context.
`core:ask` routes to the right flow when you are unsure. Run `core:setup` once
per repo to configure the issue tracker, triage labels, and domain docs.

| Stage | Artifact | Skills |
| --- | --- | --- |
| Shape the idea | `GLOSSARY.md`, ADRs | `grill-with-docs`, `grill-me`, `grilling`, `domain-modeling`, `prototype`, `research` |
| Spec and tickets | spec and tickets in the configured tracker | `to-spec`, `to-tickets` |
| Build | code on the current or integration branch | `implement`, `implement-spec`, `tdd` |
| Verify | real behavior and test evidence | `verify`, `e2e-scenario-testing`, `diagnosing-bugs` |
| Review | findings and cleanups | `code-review`, `simplify` |
| Deliver | PR; requested release/deployment | `create-pr` includes [PR writing](skills/create-pr/references/pr-writing.md); `ship` handles deployment |

## On-ramps

| Need | Route |
| --- | --- |
| Incoming bugs or requests | `triage` → `implement` |
| Something is broken | `diagnosing-bugs` |
| Huge, foggy effort across sessions | `wayfinder` → `to-spec` → `to-tickets` → `implement` |
| Session continuity | `handoff` carries context; `retro` improves the environment |

## Independent and supporting skills

| Area | Skills |
| --- | --- |
| Codebase vocabulary and upkeep | `codebase-design`, `improve-codebase-architecture`, `writing-for-agents` |
| Communication and incoming work | `to-questionnaire`, `wait-what`, `writing-rfcs` |
| Learning and interfaces | `learn` (workspace: `~/.skills/learn/<topic>/`), `browser`, `wizard` |
| Design alternatives | `competitive-agents` |

## Agents and hooks

`researcher` gathers current documentation and version-specific evidence.
Existing hooks remain in place: `WorktreeCreate` sets up the worktree,
`PreToolUse` protects git operations, and agent-status hooks handle session,
prompt, permission, stop, and end events. They use the shared `hooks/` assets.

## Migration and provenance

See the root [installation migration](../../README.md#migrating-an-existing-installation)
to remove the old `mattpocock-skills` and `me` packages and install
`core`. The obra/superpowers workflow is the separate `superpower` plugin. Historical plans and designs keep their
original names. [Upstream snapshots and MIT notices](upstream/README.md) are
preserved separately from the live workflow.
