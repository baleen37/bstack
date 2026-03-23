<!-- Generated: 2026-02-01 | Updated: 2026-02-20 -->

# me

## Purpose

bstack - AI 코딩 어시스턴트 툴킷 (Claude Code, OpenCode, 그 외)

AI 보조 개발을 위한 도구들을 제공하며, 반복적 자기 참조 AI 개발 루프(Ralph Loop), Git 워크플로우 보호, 개인용 개발 워크플로우 자동화 등의 기능을 포함합니다.

## Key Files

| File | Description |
| ---- | ----------- |
| `package.json` | Project dependencies and scripts (commitizen, husky, semantic-release) |
| `.releaserc.js` | Semantic-release configuration for root plugin version management |
| `CLAUDE.md` | Project guidance for Claude Code (architecture, commands, guidelines) |
| `README.md` | Project overview and documentation |
| `flake.nix` | Nix flake for reproducible development environment |
| `.pre-commit-config.yaml` | Pre-commit hooks configuration (YAML, JSON, ShellCheck, markdownlint, commitlint) |
| `.commitlintrc.js` | Commitlint configuration for Conventional Commits |
| `.gitignore` | Git ignore patterns |

## Subdirectories

| Directory | Purpose |
| --------- | ------- |
| `hooks/` | Hook scripts and unified hooks.json |
| `scripts/` | Utility scripts (handoff, conflict checks, PR verification) |
| `skills/` | Standalone skills (see `skills/AGENTS.md`) |
| `dist/` | Compiled JavaScript files |
| `.claude-plugin/` | Marketplace configuration and root plugin.json |
| `.github/` | GitHub Actions workflows and custom actions (see `.github/AGENTS.md`) |
| `tests/` | BATS test suites (see `tests/AGENTS.md`) |
| `schemas/` | JSON schemas for validation (see `schemas/AGENTS.md`) |
| `docs/` | Development and testing documentation (see `docs/AGENTS.md`) |
| `.husky/` | Git hooks managed by husky |
| `.worktrees/` | Git worktrees for parallel development |
| `.reports/` | Analysis reports (e.g., dead code analysis) |
| `.claude/` | Claude Code session data |

## For AI Agents

### Working In This Directory

- Always run `bun install` after modifying package.json
- Use Conventional Commits format: `type(scope): description`
- Use `bun run commit` for interactive commit creation (works via Bun's npm compatibility)
- Never bypass pre-commit hooks with `--no-verify` (blocked by git-guard)
- Follow semantic-release workflow for version management

### Testing Requirements

- Run `bats tests/` before committing
- Ensure all pre-commit hooks pass: `pre-commit run --all-files`

### Common Patterns

- Single plugin: `.claude-plugin/plugin.json` at root level — no subdirectory scanning
- Version synchronization: `.releaserc.js` updates root plugin.json and marketplace.json
- Portable paths: Use `${CLAUDE_PLUGIN_ROOT}` in hook scripts
- Hook script requirements: `set -euo pipefail`, jq for JSON parsing, stderr for errors

## Dependencies

### External

- **Bun** - Runtime environment and package manager (>= 1.0.0)
- **semantic-release** - Automated version management
- **commitizen/commitlint** - Conventional Commits enforcement
- **husky** - Git hooks management
- **pre-commit** - Pre-commit hooks framework (Python-based)
- **BATS** - Bash Automated Testing System
- **Nix** (optional) - Reproducible development environment

### Development Tools

- **jq** - JSON parsing in shell scripts
- **ShellCheck** - Shell script linting
- **markdownlint** - Markdown linting
- **YAML linting** - YAML validation

<!-- MANUAL: Project-specific notes below this line are preserved -->
