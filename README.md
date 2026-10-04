# skills

An AI coding assistant toolkit. It is designed for both Claude Code and Codex,
and bundles personal workflow automation, safer Git operations, session handoff, LSP installation, and external tool integrations.

## Highlights

- Git protection: blocks dangerous commands such as `--no-verify`
- Session handoff: carries work context into the next session
- LSP auto-installation: Bash, TypeScript, Python, Go, Kotlin, Lua, Nix, Terraform
- Iterative development loop: PRD-driven automated improvement cycles
- Personal skills: commit, review, research, PR creation, E2E verification
- External integrations: Slack, Atlassian, Datadog

## Installation

Install directly from the GitHub marketplace.

```bash
claude plugin marketplace add https://github.com/baleen37/skills
claude plugin install core@skills
```

## Codex Compatibility

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
| `core` | Matt Pocock's engineering flow plus verification, review, PRs, and shipping (34 skills) |
| `superpower` | obra/superpowers workflow: brainstorming, plans, subagent-driven execution, code review (12 skills) |
| `slack` | Slack message, thread, channel, and user search |
| `atlassian` | Jira work guidance through `twg` |
| `datadog` | Logs, monitors, APM, and metric investigation |
| `autoresearch` | Automated experiment loop driven by metrics |

## Default Development Flow

`core:grill-with-docs` → `core:to-spec` → `core:to-tickets` → `core:implement` or
`core:implement-spec` → `core:verify` → `core:code-review` → `core:create-pr`.

Small changes go straight to `core:implement`. `core:ask` routes to the right flow
when you are unsure. Run `core:setup` once per repo to configure the issue tracker.

See the [core README](plugins/core/README.md) for all features and optional paths.

## Migrating an Existing Installation

Once this unified version is released, remove the old `mattpocock-skills` and `me`
plugins and install `core`. `superpower` remains a separate, optional plugin. The old namespaces have no aliases.
The examples below assume the marketplace was registered as `bstack` with the `user` scope.
If you installed it as `baleen-marketplace`, change the name; if you used another scope, adjust accordingly.

Claude Code:

```bash
claude plugin uninstall mattpocock-skills@bstack --scope user --keep-data
claude plugin uninstall me@bstack --scope user --keep-data
claude plugin marketplace update bstack
claude plugin install core@bstack --scope user
```

Codex:

```bash
codex plugin remove mattpocock-skills@bstack
codex plugin remove me@bstack
codex plugin marketplace upgrade bstack
codex plugin add core@bstack
```

Skip the removal command for any old plugin you never installed. After updating, open a
new session and confirm that `core:ask` and `core:implement` are discovered. Past design and
plan documents are kept as historical records; update any in-progress plan to the current
`core:` invocations before executing it.

## Project Structure

```text
skills/
├── plugins/              # Plugin sources
│   ├── core/             # Personal workflow plugin
│   ├── slack/            # Slack integration
│   ├── atlassian/        # Jira guidance through twg
│   ├── datadog/          # Datadog integration
│   └── autoresearch/     # Automated experiment loop
├── scripts/              # Sync and utility scripts
├── tests/                # BATS tests
└── CLAUDE.md             # Project guidance for AI agents
```

## Development

### Testing

```bash
bun run test
pre-commit run --all-files
```

### Checking Codex Artifacts

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
- JSON syntax
- GitHub Actions workflows (actionlint)
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
