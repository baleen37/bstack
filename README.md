# Everything Agent

AI coding assistant toolkit - Claude Code, OpenCode, and more.

## Available Plugins

Plugins are automatically discovered from the `plugins/` directory. For detailed
information about each plugin, see the respective plugin's README.md file.

- **ralph-loop**: Implementation of the Ralph Wiggum technique for iterative,
  self-referential AI development loops
- **git-guard**: Git workflow protection hooks that prevent commit and PR
  bypasses (automatic, no commands needed)
- **me**: Personal development workflow automation with 8 commands, 1 agent,
  and 7 skills (TDD, debugging, git, code review, research, orchestration)
- **jira**: Jira integration with 5 powerful skills - triage bugs, capture
  tasks from meeting notes, generate status reports, search company knowledge,
  and convert specs to backlogs. Uses Atlassian's MCP server with OAuth 2.1.
- **strategic-compact**: Strategic content compaction and organization tools
  (automatic PreToolUse hook)

## Quick Start

### Installation from GitHub

```bash
# Add this repository as a marketplace
claude plugin marketplace add https://github.com/baleen37/everything-agent

# Install a plugin
claude plugin install ralph-loop@everything-agent
claude plugin install git-guard@everything-agent
```

### Using Ralph Loop

```bash
# Start Claude Code with ralph-loop
claude

# In Claude Code, start a loop
/ralph-loop "Build a REST API for todos with tests" --max-iterations 20 --completion-promise "COMPLETE"

# Cancel if needed
/cancel-ralph
```

### Using Git Guard

Git Guard operates automatically via PreToolUse hooks - no commands needed:

- `git commit --no-verify` is automatically blocked
- Pre-commit validation is enforced
- Works transparently in the background

### Using "me" Plugin (Personal Workflow)

The "me" plugin provides comprehensive development workflow automation:

**Commands (8):**

- `/brainstorm` - Brainstorming and feature planning
- `/create-pr` - Full git workflow (commit → push → PR)
- `/debug` - Systematic debugging process
- `/orchestrate` - Sequential agent workflow execution
- `/refactor-clean` - Code refactoring and cleanup
- `/research` - Web research with citations
- `/sdd` - Subagent-driven development approach
- `/verify` - Comprehensive codebase verification

**Agents (1):**

- `code-reviewer` - Code review against plans and standards

**Skills (7):**

- `ci-troubleshooting` - Systematic CI debugging
- `test-driven-development` - TDD methodology
- `systematic-debugging` - Root cause analysis
- `using-git-worktrees` - Isolated feature work
- `setup-precommit-and-ci` - Pre-commit and CI setup
- `nix-direnv-setup` - Nix flake direnv integration
- `writing-claude-code` - Creating Claude Code components

## Project Structure

```text
everything-agent/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace configuration (everything-agent)
├── plugins/                      # Plugins (auto-discovered)
│   ├── ralph-loop/              # Ralph Wiggum technique implementation
│   │   ├── commands/             # Slash commands (/ralph-init, /ralph-loop, /cancel-ralph, /help)
│   │   ├── scripts/              # Core loop script (ralph.sh) and prompt template
│   │   └── tests/                # BATS tests
│   ├── git-guard/               # Git workflow protection
│   │   ├── hooks/                # PreToolUse hook
│   │   └── tests/                # BATS tests
│   ├── me/                      # Personal workflow automation
│   │   ├── commands/             # 8 commands (brainstorm, create-pr, debug, etc.)
│   │   ├── agents/               # Code reviewer agent
│   │   ├── skills/               # 7 skills (ci-troubleshooting, tdd, etc.)
│   │   └── tests/                # BATS tests
│   ├── jira/                    # Jira integration
│   │   └── agents/               # Jira MCP agents
│   └── strategic-compact/       # Content compaction
│       └── hooks/                # PreToolUse hook (suggests compaction)
├── .github/workflows/            # CI/CD workflows
├── docs/                         # Development and testing documentation
├── tests/                        # BATS tests
├── schemas/                      # JSON schemas
└── CLAUDE.md                     # Project instructions for Claude Code
```

## Development

### Creating Your Own Plugin

1. Reference existing plugins (e.g., `git-guard`) for structure
2. Create plugin directories:

```bash
mkdir -p plugins/my-plugin/.claude-plugin
mkdir -p plugins/my-plugin/commands
mkdir -p plugins/my-plugin/hooks
```

1. Create `plugins/my-plugin/.claude-plugin/plugin.json`
2. Add your commands, agents, skills, or hooks
3. Update `plugins/my-plugin/README.md`
4. Add to `.claude-plugin/marketplace.json`

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
- `docs`, `style`, `refactor`, `test`, `build`, `ci`, `chore`: No version bump

**Scope:** Plugin name (`ralph-loop`, `git-guard`, etc.)

**Examples:**

```text
feat(ralph-loop): add iteration progress tracking
fix(git-guard): prevent --no-verify bypass
docs(me): update skill documentation
```

#### Release Process

1. Push commits to main branch
2. GitHub Actions runs tests then semantic-release
3. Version is determined (feat → minor, fix → patch)
4. Each `plugin.json` and `marketplace.json` is updated
5. Git tag is created and GitHub release is published

### Jira MCP Server Setup

The Jira plugin requires MCP server configuration:

1. Install the Atlassian MCP server
2. Configure OAuth 2.1 authentication
3. Add MCP server configuration to Claude Code settings

See `plugins/jira/README.md` for detailed setup instructions.

### Component Types

- **Commands** (`commands/*.md`): Slash commands invoked by users (e.g., `/brainstorm`)
- **Agents** (`agents/*.md`): Autonomous experts that execute specific tasks
- **Skills** (`skills/*/SKILL.md`): Context-aware guides that activate automatically
- **Hooks** (`hooks/hooks.json` + `hooks/*.sh`): Event-driven automation (SessionStart, PreToolUse, etc.)

## Ralph Loop Philosophy

Ralph embodies several key principles:

1. **Iteration > Perfection**: Don't aim for perfect on first try. Let the loop refine the work.
2. **Failures Are Data**: "Deterministically bad" means failures are predictable and informative.
3. **Operator Skill Matters**: Success depends on writing good prompts, not just having a good model.
4. **Persistence Wins**: Keep trying until success.

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
4. **Documentation** - Update README.md for plugin changes

## License

MIT License - see [LICENSE](LICENSE) file.
