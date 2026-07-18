# bstack

An AI coding assistant toolkit. It is designed for both Claude Code and Codex, and bundles personal workflow automation, safer Git operations, session handoff, LSP installation, and external tool integrations.

## Highlights

- Git protection: blocks dangerous commands such as `--no-verify`
- Session handoff: carries work context into the next session
- LSP auto-installation: Bash, TypeScript, Python, Go, Kotlin, Lua, Nix, Terraform
- Iterative development loop: PRD-driven automated improvement cycles
- Personal skills: commit, review, research, PR creation, E2E verification
- External integrations: Jira, Slack, Notion, Datadog

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

## Plugins

| Plugin | Purpose |
| --- | --- |
| `me` | Personal workflow, handoff, commits, PRs, research, E2E, review |
| `jira` | Jira search, creation, comments, and triage |
| `slack` | Slack message, thread, channel, and user search |
| `notion` | Notion page and database search, document writing |
| `datadog` | Logs, monitors, APM, and metric investigation |
| `autoresearch` | Automated experiment loop driven by metrics |

## Project Structure

```text
bstack/
├── plugins/              # Plugin sources
│   ├── me/               # Personal workflow plugin
│   ├── jira/             # Jira integration
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
