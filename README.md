# bstack

An AI coding assistant toolkit — Claude Code, OpenCode, and more.

## Features

bstack is a unified package bundled as plugins:

- **Git Guard**: Automatically blocks dangerous git commands such as `--no-verify`
- **Session Handoff**: Hands off and resumes context across Claude sessions
- **LSP Servers**: Auto-installs language servers for Bash, TypeScript, Python, Go, Kotlin, Lua, Nix, and Terraform
- **Ralph Loop**: PRD-driven automated iterative development loop
- **Skills**: A collection of personal development workflow skills
- **Jira Integration**: Jira issue triage, backlog generation, status reports, and more

## Quick Start

### Installation from GitHub

```bash
# Add this repository as a marketplace
claude plugin marketplace add https://github.com/baleen37/bstack

# Install the plugin
claude plugin install bstack
```

## Codex Compatibility

This repository keeps Claude Code metadata as the source of truth and generates Codex plugin artifacts from it.

- Generated files: `plugins/*/.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`
- Shared content: `plugins/*/skills/**`
- Do not edit generated Codex files directly

To refresh the committed Codex artifacts locally:

```bash
bun run sync:codex
```

## Project Structure

```text
bstack/
├── plugins/
│   ├── me/                    # Core personal workflow plugin
│   │   ├── hooks/             # Session hooks (git guard, handoff, LSP checks)
│   │   └── skills/            # Personal skills
│   ├── jira/                  # Jira plugin backed by a slim Atlassian MCP facade
│   ├── slack/                 # Slack plugin backed by Slack MCP
│   ├── notion/                # Notion plugin backed by Notion MCP
│   ├── datadog/               # Datadog plugin backed by pup CLI
│   │   └── skills/            # Jira workflow skills
│   ├── core/                  # Shared agent definitions
│   ├── lsp-*/                 # Individual LSP plugins (bash, go, lua, etc.)
├── scripts/                   # Utility scripts (handoff, dispatch, version sync)
├── docs/                      # Development and testing documentation
├── tests/                     # BATS tests
├── schemas/                   # JSON schemas
└── CLAUDE.md                  # Project instructions for Claude Code
```

### Skills

#### `me` plugin (personal workflow)

| Skill | Description |
|-------|-------------|
| `handoff` | Generate a handoff document for the next session at session end |
| `create-pr` | Unified workflow to commit, push, and create a PR |
| `commit` | Commit using Conventional Commits format |
| `research` | Explore the codebase and investigate bugs |
| `e2e` | End-to-end verification across multiple components |
| `iterate` | Incremental improvement via repeated single-change cycles |
| `competitive-agents` | Explore designs with parallel competing agents |
| `remembering-conversations` | Search and apply prior conversation context |
| `review-claudemd` | Surface improvements for CLAUDE.md |
| `reddit-fetch` | Fetch Reddit content when WebFetch is blocked |

#### `autoresearch` plugin

| Skill | Description |
|-------|-------------|
| `autoresearch` | Autonomous experiment loop that iteratively optimizes a metric with git-tracked experiments |

#### `jira` plugin

| Skill | Description |
|-------|-------------|
| `jira` | Search, create, comment, and triage Jira via a slim Atlassian MCP facade |

#### `slack` plugin

| Skill | Description |
|-------|-------------|
| `slack-search` | Search messages, files, channels, users, and threads via the official Slack MCP |
| `slack-messaging` | Draft, reply to, and post messages via the official Slack MCP |

#### `notion` plugin

| Skill | Description |
|-------|-------------|
| `notion-search` | Search pages and databases via the official Notion MCP |
| `notion-document-writing` | Create and update documents via the official Notion MCP |

#### `datadog` plugin

| Skill | Description |
|-------|-------------|
| `datadog` | Investigate logs, monitors, APM, and metrics via the `pup` CLI |

## Development

### Running Tests

```bash
# Run all BATS tests
bats tests/

# Run pre-commit hooks manually
pre-commit run --all-files
```

### Version Management & Release

This project manages versions automatically using **semantic-release** and **Conventional Commits**.

```bash
# Interactive commit (recommended)
bun run commit

# Or write manually
git commit -m "type(scope): description"
```

**Types:**

- `feat`: New feature (minor version bump)
- `fix`: Bug fix (patch version bump)
- `docs`, `style`, `refactor`, `test`, `build`, `ci`, `chore`, `perf`: Patch version bump

#### Release Process

1. Push commits to main branch
2. GitHub Actions runs tests then semantic-release
3. Version is determined (feat → minor, fix → patch)
4. `marketplace.json` and each `plugins/*/.claude-plugin/plugin.json` are updated
5. Git tag is created and GitHub release is published

## Pre-commit Hooks

```bash
pre-commit run --all-files
```

**Validations:**

- YAML syntax validation
- JSON schema validation
- ShellCheck (shell script linting)
- markdownlint (Markdown linting)
- commitlint (commit message format)

> Note: Pre-commit failures cannot be bypassed with `--no-verify` (enforced by git-guard).

## Contributing

1. **Conventional Commits** - Use `bun run commit` for interactive commit creation
2. **Pre-commit Hooks** - All hooks must pass before committing
3. **Test Coverage** - Add BATS tests for new features
4. **Documentation** - Update README.md for changes

## License

MIT License - see [LICENSE](LICENSE) file.
