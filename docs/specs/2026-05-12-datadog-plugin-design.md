# Datadog Plugin Design

Date: 2026-05-12
Status: Approved, ready for implementation plan

## Purpose

Add a `datadog` plugin to the bstack repo so Claude Code can perform Datadog operations through the `pup` CLI. Mirror a curated subset of skills from the upstream `DataDog/pup` repository's `skills/` directory and align their frontmatter to the bstack convention.

## Background

- `pup` is Datadog Labs' official Rust-based CLI: 200+ commands across 33+ Datadog products, OAuth2/API-key auth, JSON/Table/YAML output, automatic agent-mode output for AI coding assistants.
- The upstream repo `DataDog/pup` ships 9 skills under `skills/` (each a single `SKILL.md`). They are the intended entry point for AI agents working with pup.
- An older `DataDog/datadog-api-claude-plugin` exists but is archived; we do not depend on it.
- The bstack repo already follows a `plugins/<name>/skills/<skill>/SKILL.md` convention with a flat `name` + `description` frontmatter (no `metadata` block), as used by the `me` and `jira` plugins.

## Decisions

| Item | Decision |
|---|---|
| Direction | Curated mirror, aligned to bstack style |
| Skills mirrored | `dd-pup`, `dd-logs`, `dd-monitors`, `dd-apm`, `dd-docs` (5 of 9) |
| Skills excluded | `dd-debugger`, `dd-symdb`, `dd-code-generation`, `dd-file-issue` |
| Frontmatter | `name` + `description` only; upstream `metadata` block removed |
| Skill bodies | Mirrored verbatim from upstream |
| Skill names | Kept as upstream (`dd-pup`, ...) for sync traceability |
| Plugin name | `datadog` |
| pup install handling | README guidance only, no hooks |
| Extra workflow skills | None at this stage |

### Why these 5 skills

- `dd-pup` — core CLI auth and patterns, prerequisite for the others.
- `dd-logs`, `dd-monitors`, `dd-apm` — the day-to-day observability surface.
- `dd-docs` — small (75 lines), useful as a docs lookup companion.

### Why the others are excluded

- `dd-debugger` and `dd-symdb` — Live Debugger / Symbol DB; only valuable when actively placing runtime probes on production services. Add later if that workflow appears.
- `dd-code-generation` — 551 lines, focused on generating Datadog SDK integration code for app code. Heavy and out of scope for current needs.
- `dd-file-issue` — files GitHub issues against pup/plugin itself; meta-tooling for upstream maintainers, not for our use.

## File Structure

```
plugins/datadog/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── SYNC.md
└── skills/
    ├── dd-pup/SKILL.md
    ├── dd-logs/SKILL.md
    ├── dd-monitors/SKILL.md
    ├── dd-apm/SKILL.md
    └── dd-docs/SKILL.md
```

`.claude-plugin/marketplace.json` at repo root gains a `datadog` entry alongside existing `jira`, `me`, `ralph`, `autoresearch`.

## Frontmatter Transformation

Upstream:

```yaml
---
name: dd-logs
description: Log management - search, pipelines, archives, and cost control.
metadata:
  version: "1.0.0"
  author: datadog-labs
  repository: https://github.com/datadog-labs/agent-skills
  tags: datadog,logs,logging,search,dd-logs
  globs: "**/datadog*.yaml,**/*log*"
  alwaysApply: "false"
---
```

Mirrored:

```yaml
---
name: dd-logs
description: Log management - search, pipelines, archives, and cost control.
---
```

Rules:

- `name` and `description` copied verbatim — changing them breaks sync traceability.
- Entire `metadata` block removed.
- Body of `SKILL.md` is not modified.
- One upstream skill (`dd-code-generation`) uses a different frontmatter shape (no `name:`, `description:` + `tags:` array). It is excluded from the mirror, so this case does not apply.

## SYNC.md

Records:

- Upstream URL: `https://github.com/DataDog/pup`
- Upstream commit SHA at time of mirror (HEAD of `main`)
- The 5 mirrored skill paths under `skills/`
- Short note on why the other 4 were excluded (mirrors the table above)
- Sync procedure: sparse-clone upstream, copy bodies for the 5 skills, rewrite frontmatter per the rules above, bump the recorded SHA

## README.md

- One-line description of the plugin
- `pup` install: `brew tap datadog-labs/pack && brew install datadog-labs/pack/pup`
- Auth: `pup auth login` (OAuth2, recommended) or `DD_API_KEY` / `DD_APP_KEY` / `DD_SITE` env vars
- List of included skills with one-line descriptions
- Upstream source attribution

## plugin.json

Match the shape used by the existing `plugins/jira/.claude-plugin/plugin.json` and `plugins/me/.claude-plugin/plugin.json` — exact keys to be confirmed against those files during implementation.

## Marketplace Entry

Add a `datadog` entry to `.claude-plugin/marketplace.json` following the format of existing entries.

## Verification

- `bats tests/` passes — existing suites unbroken.
- `pre-commit run --all-files` passes — markdownlint, YAML, JSON, ShellCheck clean.
- `marketplace.json` parses as valid JSON and the new entry validates against any existing schema in `schemas/`.
- Each `SKILL.md` frontmatter parses as valid YAML.
- Plugin loads in Claude Code; `Skill` tool can invoke `datadog:dd-logs`, `datadog:dd-pup`, etc.

## Out of Scope

- Authentication automation or credential storage beyond what `pup` itself provides.
- A `PreToolUse` hook that validates `pup` is installed before invocation.
- Custom workflow skills layered on top of the mirrored ones (e.g., incident-context, alert-to-jira). May be revisited after real usage.
- Mirroring the excluded 4 skills. Revisit if/when their workflows become relevant.
