# core plugin

Install `core` for development tools shared by Claude Code and Codex.
It contains 23 skills: TDD and debugging, verification, review, PR creation,
deployment, and independent engineering tools. Planning and execution flows
live in the separate `superpower` plugin.

## Default workflow

`superpower:brainstorming` → `superpower:writing-plans` →
`superpower:executing-plans` or `superpower:subagent-driven-development` →
`core:verify` → `core:code-review` → `core:create-pr`.

| Stage | Artifact | Skills |
| --- | --- | --- |
| Shape the idea | `GLOSSARY.md`, ADRs, prototypes, research notes | `domain-modeling`, `prototype`, `research` |
| Build | code | `tdd` |
| Verify | real behavior and test evidence | `verify`, `e2e-scenario-testing`, `diagnosing-bugs` |
| Review | findings and cleanups | `code-review`, `simplify` |
| Deliver | PR; requested release/deployment | `create-pr` includes [PR writing](skills/create-pr/references/pr-writing.md); `ship` handles deployment |

## Independent and supporting skills

| Area | Skills |
| --- | --- |
| Codebase vocabulary and upkeep | `codebase-design`, `improve-codebase-architecture`, `writing-for-agents` |
| Communication | `to-questionnaire`, `wait-what`, `writing-rfcs` |
| Session continuity | `handoff` carries context; `retro` improves the environment |
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
`core`. The obra/superpowers workflow is the separate `superpower` plugin.
Historical plans and designs keep their original names.
[Upstream snapshots and MIT notices](upstream/README.md) are
preserved separately from the live workflow.
