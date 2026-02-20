# Everything Agent

AI coding assistant toolkit - Claude Code, OpenCode, and more.

## Features

Everything Agent is a single consolidated plugin providing:

- **LSP Servers**: Bash, TypeScript, Python, Go, Kotlin, Lua, Nix language server integration
- **Git Guard**: Automatic git workflow protection (blocks `--no-verify`, etc.)
- **Session Handoff**: Smooth context transfer between Claude sessions
- **Context Management**: Intelligent compaction suggestions for long conversations
- **Skills**: Personal development workflow skills (GHA debugging, handoff, Reddit fetch, etc.)

## Quick Start

### Installation from GitHub

```bash
# Add this repository as a marketplace
claude plugin marketplace add https://github.com/baleen37/everything-agent

# Install the plugin
claude plugin install everything-agent
```

### Using Git Guard

Git Guard operates automatically via PreToolUse hooks - no commands needed:

- `git commit --no-verify` is automatically blocked
- Pre-commit validation is enforced
- Works transparently in the background

### Using Session Handoff

The handoff system runs automatically at SessionStart and provides commands to transfer context between sessions.

## Project Structure

```text
everything-agent/
├── .claude-plugin/
│   ├── plugin.json               # Root plugin configuration
│   └── marketplace.json          # Marketplace configuration
├── hooks/
│   ├── hooks.json                # Unified hooks (SessionStart + PreToolUse)
│   ├── commit-guard.sh           # Git workflow protection
│   ├── handoff-session-start.sh  # Session handoff trigger
│   └── lsp-*-check-install.sh   # LSP server install checks (7 languages)
├── scripts/
│   ├── handoff.sh                # Handoff script
│   ├── pickup.sh                 # Pickup script
│   ├── handoff-list.sh           # List handoffs
│   ├── check-conflicts.sh        # Conflict checker
│   ├── verify-pr-status.sh      # PR status verifier
│   ├── sync-marketplace-version.sh # Version sync utility
│   ├── ralph/                    # Ralph loop scripts
│   └── databricks-devtools/      # Databricks CLI scripts
├── skills/                       # All skills (18 total)
│   ├── gha/                      # GitHub Actions debugging
│   ├── handoff/                  # Handoff skill
│   ├── reddit-fetch/             # Reddit content fetcher
│   ├── remembering-conversations/ # Conversation memory
│   ├── review-claudemd/          # CLAUDE.md review
│   └── ...                       # Additional skills
├── dist/
│   ├── auto-compact.js           # Auto-compaction (PreToolUse)
│   └── session-start.js          # Session start compaction check
├── .github/workflows/            # CI/CD workflows
├── docs/                         # Development and testing documentation
├── tests/                        # BATS tests
├── schemas/                      # JSON schemas
└── CLAUDE.md                     # Project instructions for Claude Code
```

## Development

### Running Tests

```bash
# Run all BATS tests
bats tests/

# Run specific test file
bats tests/directory_structure.bats

# Run pre-commit hooks manually
pre-commit run --all-files
```

### Version Management & Release

This project uses **semantic-release** with **Conventional Commits** for
automated version management.

#### Commit Message Format (Conventional Commits)

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

**Examples:**

```text
feat: add new LSP language server support
fix: correct handoff session-start path
docs: update installation instructions
```

#### Release Process

1. Push commits to main branch
2. GitHub Actions runs tests then semantic-release
3. Version is determined (feat → minor, fix → patch)
4. Root `plugin.json` and `marketplace.json` are updated
5. Git tag is created and GitHub release is published

### Component Types

- **Skills** (`skills/*/SKILL.md`): Context-aware guides that activate automatically
- **Hooks** (`hooks/hooks.json` + `hooks/*.sh`): Event-driven automation (SessionStart, PreToolUse, etc.)
- **Scripts** (`scripts/*.sh`): Utility scripts for handoff and workflow automation

## Pre-commit Hooks

This project uses pre-commit hooks for code quality:

```bash
# Run pre-commit manually
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

Contributions are welcome! This project follows:

1. **Conventional Commits** - Use `bun run commit` for interactive commit creation
2. **Pre-commit Hooks** - All hooks must pass before committing
3. **Test Coverage** - Add BATS tests for new features
4. **Documentation** - Update README.md for changes

## License

MIT License - see [LICENSE](LICENSE) file.
