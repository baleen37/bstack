# Me

Personal Claude Code configuration - TDD, systematic debugging, git workflow, code review, and development automation.

## Components

### Commands (10)

- **brainstorm**: Brainstorming and planning
- **create-pr**: Commit, push, and create/update pull requests
- **debug**: Systematic debugging process
- **orchestrate**: Execute sequential agent workflows
- **refactor-clean**: Code refactoring and cleanup
- **research**: Web research with citations
- **sdd**: Subagent-driven development approach
- **spawn**: Create new git worktree for isolated feature work
- **tdd**: Test-driven development workflow
- **verify**: Comprehensive codebase verification

### Agents

- **code-reviewer**: Review code against plans and standards

### Skills (3)

- **ci-troubleshooting**: Systematic CI debugging approach
- **spawn-worktree**: Isolated feature work with git worktrees
- **test-driven-development**: TDD methodology and workflow

## Installation

```bash
/plugin marketplace add /path/to/claude-plugins
/plugin install me@claude-plugins
```

## Usage

This plugin provides a comprehensive set of tools for:

- Git workflow automation (commit, PR, worktree management)
- CI/CD troubleshooting and debugging
- Nix flakes development environment setup
- Code review and quality assurance
- Handoff between sessions

## Philosophy

Following strict TDD and systematic debugging practices. All features and bugfixes
follow test-driven development, and root cause analysis is mandatory for any issue
resolution.

## Repository

Part of the [dotfiles](https://github.com/baleen37/dotfiles) project - Nix
flakes-based reproducible development environments for macOS and NixOS.
