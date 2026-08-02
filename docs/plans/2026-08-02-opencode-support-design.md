# OpenCode Support Design

**Date:** 2026-08-02
**Branch:** feat-setup-oc
**Status:** Approved

## Goal

Add OpenCode support to bstack. Claude Code metadata stays the source of
truth; a generation pipeline produces committed OpenCode artifacts (mirroring
the existing Codex pipeline). Users install the artifacts into
`~/.config/opencode/` with a symlink script.

Scope (confirmed): skills + agents + commands + commit-guard hook port.
`setup-worktree` and `agent-status` hooks have no OpenCode equivalent and are
excluded. Agents drop their `model` field and inherit the OpenCode default.
Skill names stay as-is. Install is via symlink.

## Research Summary

Three parallel research tasks (opencode docs, plugin API, repo pipeline):

- OpenCode has no marketplace. Load locations: skills (`/docs/skills`), agents
  (`~/.config/opencode/agents/*.md`), commands (`~/.config/opencode/command/*.md`),
  plugins (`.opencode/plugins/*.ts` or npm). Skill names must be globally unique.
- `tool.execute.before` receives `{ tool, sessionID, callID }` and
  `output.args.command` for bash; blocking is done by throwing.
  `shell.env` injects env vars into both the AI bash tool and user terminals.
  `import.meta.dir` resolves symlinks to the real source directory, so the
  plugin works from `.opencode/plugins/` or a symlink in the global config.
  Type-only imports are erased (no `package.json` needed); value imports break
  under symlinks and must be avoided.
- The Codex pipeline (eligible-plugin selection, atomic mktemp+cmp writes,
  drift check via `git diff --exit-code`, `.releaserc.js` prepare hook, CI
  sync/drift steps) maps cleanly to OpenCode.

## Artifact Layout (generated, committed)

```
.opencode/
├── skills/            13 skills copied wholesale (scripts/, references/, evals/ included)
├── agents/            4 agents converted from plugins/me/agents/*.md
├── command/           autoresearch.md converted
└── plugins/
    └── bstack.ts      commit-guard port + CLAUDE_PLUGIN_ROOT injection
```

### Conversion Rules

| Asset | Source | Rule |
| --- | --- | --- |
| Skills | `plugins/<p>/skills/<s>/` | Copy entire dir to `.opencode/skills/<s>/`. SKILL.md is a shared format; extra frontmatter fields are ignored by OpenCode. |
| Agents | `plugins/me/agents/*.md` | Remove `model: sonnet` / `model: inherit`. Add `mode: subagent`. Keep `name`, `description`, body. |
| Command | `plugins/autoresearch/commands/autoresearch.md` | Remove `argument-hint` and `allowed-tools`. Keep `description` and body. |
| Plugin | `scripts/opencode-plugin/bstack.ts` | Copy verbatim. |

### `bstack.ts` Plugin

- `"tool.execute.before"`: when `input.tool === "bash"`, inspect
  `output.args.command`; throw to block dangerous git patterns
  (`git commit --no-verify`, matching the existing `commit-guard.sh` logic).
- `"shell.env"`: set `CLAUDE_PLUGIN_ROOT` to the `.opencode/` root computed via
  `import.meta.dir`, so SKILL.md bodies that reference
  `${CLAUDE_PLUGIN_ROOT}/skills/...` resolve.
- Dependency-free plain TS. No value imports.

## Scripts

| File | Role |
| --- | --- |
| `scripts/generate-opencode-artifacts.sh` | Read `.claude-plugin/marketplace.json`; eligible = plugins with `skills/` dir. Build `.opencode/` (skills copy, agents/commands converted, plugin copied). Atomic mktemp+cmp writes; prune stale artifacts. |
| `scripts/sync-opencode-artifacts.sh` | Runs the generator. |
| `scripts/check-opencode-artifacts.sh` | Run sync, then `git diff --exit-code -- .opencode/` plus untracked check. |
| `scripts/install-opencode.sh` | Symlink `.opencode/{skills,agents,command}` contents and `plugins/bstack.ts` into `~/.config/opencode/`. |
| `scripts/opencode-plugin/bstack.ts` | Source template for the generated plugin. |

## Wiring

- `package.json`: add `sync:opencode`, `check:opencode`, `install:opencode`.
- `.releaserc.js`: in `prepare`, also run `bash scripts/sync-opencode-artifacts.sh`;
  add `'.opencode/**'` to the `@semantic-release/git` assets.
- Workflows (`ci.yml`, `release.yml`, `sync-marketplace.yml`): add "Sync
  OpenCode artifacts" (before tests) and "Check OpenCode artifact drift" (after
  tests) steps.
- `.gitignore`: `.opencode/` stays tracked (no change).

## Tests

`tests/opencode_artifacts.bats` (mirror of the codex BATS):

- All 13 skills present in `.opencode/skills/`, matching source.
- 4 agents present; frontmatter has `mode: subagent`, no `model:`.
- `command/autoresearch.md` has `description`, no `allowed-tools`/`argument-hint`.
- `plugins/bstack.ts` contains `tool.execute.before`, `shell.env`,
  `CLAUDE_PLUGIN_ROOT`.
- Drift: run sync, expect `git diff --exit-code` clean.
- `tests/github_workflows.bats`: sync step also calls the opencode sync script.

## Docs

- README: OpenCode install section (`bun run sync:opencode` +
  `bun run install:opencode`), structure, constraints.
- CLAUDE.md: add OpenCode artifact rule (generated files must not be edited
  directly; regenerate with `bun run sync:opencode`).

## Known Constraints

- `setup-worktree` / `agent-status` hooks have no OpenCode equivalent (excluded).
- Skill names must be globally unique in OpenCode; keeping current names. On
  collision the user resolves via `permission.skill` / config.
- Agents inherit the OpenCode default model (no explicit `model:`).
