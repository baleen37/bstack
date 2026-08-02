# bstack

An AI coding assistant toolkit. It is designed for both Claude Code and Codex, and bundles personal workflow automation, safer Git operations, session handoff, LSP installation, and external tool integrations.

## Highlights

- Git protection: blocks dangerous commands such as `--no-verify`
- Session handoff: carries work context into the next session
- LSP auto-installation: Bash, TypeScript, Python, Go, Kotlin, Lua, Nix, Terraform
- Iterative development loop: PRD-driven automated improvement cycles
- Personal skills: commit, review, research, PR creation, E2E verification
- External integrations: Slack, Notion, Datadog

## 설치

Install directly from the GitHub marketplace.

```bash
claude plugin marketplace add https://github.com/baleen37/bstack
claude plugin install bstack
```

## Codex 호환성

This repository treats Claude Code metadata as the source of truth and generates Codex artifacts from it.

- Source of truth: `.claude-plugin/marketplace.json`, `plugins/*/.claude-plugin/plugin.json`
- Generated artifacts: `.agents/plugins/marketplace.json`, `plugins/*/.codex-plugin/plugin.json`
- Shared assets: `plugins/*/skills/**`
- Do not edit generated Codex files directly; regenerate them with `bun run sync:codex`

```bash
bun run sync:codex
```

## OpenCode 호환성

This repository treats Claude Code metadata as the source of truth and generates OpenCode artifacts from it.

- Source of truth: `.claude-plugin/marketplace.json`, `plugins/*/.claude-plugin/plugin.json`
- Generated artifacts: `.opencode/` bundle (skills, agents, command, `plugins/bstack.ts`)
- Generator: `scripts/generate-opencode-artifacts.sh`, template `scripts/opencode-plugin/bstack.ts`
- `.opencode/` is generated, committed, and must not be hand-edited; regenerate it with `bun run sync:opencode`

```bash
bun run sync:opencode
bun run install:opencode
```

`install:opencode` symlinks the artifacts into `~/.config/opencode/` (skills, agents, command, and the `bstack.ts` commit-guard plugin). Restart opencode after installing. The `bstack.ts` plugin blocks dangerous git commands (`--no-verify`, hook bypasses) and injects `CLAUDE_PLUGIN_ROOT` so skill scripts resolve. Notes:

- `setup-worktree` / `agent-status` Claude Code hooks have no OpenCode equivalent.
- Skill names must be globally unique in OpenCode; on collision, resolve via opencode config permissions.
- Agents inherit the OpenCode default model.

Verify generated artifacts are in sync with `bun run check:opencode`.

## Plugins

| Plugin | Purpose |
| --- | --- |
| `me` | Personal workflow, handoff, commits, PRs, research, E2E, review |
| `slack` | Slack message, thread, channel, and user search |
| `notion` | Notion page and database search, document writing |
| `datadog` | Logs, monitors, APM, and metric investigation |
| `autoresearch` | Automated experiment loop driven by metrics |

## Project Structure

```text
bstack/
├── plugins/              # Plugin sources
│   ├── me/               # Personal workflow plugin
│   ├── slack/            # Slack integration
│   ├── notion/           # Notion integration
│   ├── datadog/          # Datadog integration
│   └── autoresearch/     # Automated experiment loop
├── scripts/              # Sync and utility scripts
├── tests/                # BATS tests
├── schemas/              # JSON schemas
└── CLAUDE.md             # Project guidance for AI agents
```

## Development

### Testing

```bash
bun run test
pre-commit run --all-files
```

### Codex 아티팩트 확인

```bash
bun run check:codex
```

### Commits

This repository uses Conventional Commits and semantic-release.

```bash
bun run commit
git commit -m "type(scope): description"
```

## Release

Releases are automated.

1. Push commits to the `main` branch.
2. GitHub Actions runs the tests.
3. semantic-release determines the version.
4. `.claude-plugin/marketplace.json` and each `plugins/*/.claude-plugin/plugin.json` are synchronized.
5. A Git tag and GitHub Release are created.

## Pre-commit

Pre-commit hooks validate:

- YAML syntax
- JSON schema
- ShellCheck
- markdownlint
- commitlint

`git guard` blocks `--no-verify` bypasses, so the hooks cannot be skipped.

## Contributing

1. Use Conventional Commits.
2. After changes, run `bun run test` and `pre-commit run --all-files`.
3. Add BATS tests for new functionality.
4. Update `README.md` when documentation changes.

## License

MIT License. See [LICENSE](LICENSE) for details.
