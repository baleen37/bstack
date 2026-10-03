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
claude plugin install me@skills
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
| `me` | Unified design, plan, execution, TDD, debugging, review, verification, PRs, and shipping (41 skills) |
| `slack` | Slack message, thread, channel, and user search |
| `atlassian` | Jira work guidance through `twg` |
| `datadog` | Logs, monitors, APM, and metric investigation |
| `autoresearch` | Automated experiment loop driven by metrics |

## Default Development Flow

`me:brainstorming` → `me:writing-plans` → `me:executing-plans` or
`me:subagent-driven-development` → `me:verify` → `me:code-review` → `me:create-pr`.

For small changes, get a short design approved in brainstorming and implement it right away.
For multi-step work, review the written spec and plan, then choose how to execute it.
`me:code-review` performs the actual review; `me:requesting-code-review` and
`me:receiving-code-review` handle requesting reviews and processing feedback.

Only when there is significant uncertainty, start with `me:wayfinder` → `me:writing-spec` →
spec review → `me:writing-plans`. Specs live in `docs/specs/` by default.
Tracker publishing and `me:to-tickets` are optional; they do not automatically generate
an execution graph separate from the implementation plan. Ordinary design and
implementation work needs no tracker setup.

See the [me README](plugins/me/README.md) for all features and optional paths.

## Migrating an Existing Installation

Once this unified version is released, remove the old `superpower` and `mattpocock-skills`
plugins and update `me`. The old namespaces have no aliases.
The examples below assume the marketplace was registered as `bstack` with the `user` scope.
If you installed it as `baleen-marketplace`, change the name; if you used another scope, adjust accordingly.

Claude Code:

```bash
claude plugin uninstall superpower@bstack --scope user --keep-data
claude plugin uninstall mattpocock-skills@bstack --scope user --keep-data
claude plugin marketplace update bstack
claude plugin update me@bstack --scope user
```

Codex:

```bash
codex plugin remove superpower@bstack
codex plugin remove mattpocock-skills@bstack
codex plugin marketplace upgrade bstack
codex plugin add me@bstack
```

Skip the removal command for any old plugin you never installed. After updating, open a
new session and confirm that `me:ask` and `me:using-me` are discovered. Past design and
plan documents are kept as historical records; update any in-progress plan to the current
`me:` invocations before executing it.

## Project Structure

```text
skills/
├── plugins/              # Plugin sources
│   ├── me/               # Personal workflow plugin
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
