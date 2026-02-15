# Git Guard

Git workflow protection hooks - prevents commit and PR bypasses, enforces pre-commit checks.

## Overview

Git Guard protects your repository from bypassing quality checks through git hooks and command validation. It prevents common anti-patterns like `--no-verify` and ensures all commits pass required pre-commit checks.

## Features

### PreToolUse Hook Protection

The `PreToolUse` hook intercepts git commands before execution and blocks dangerous patterns:

**Blocked Commands:**
- `git commit --no-verify` - Bypasses pre-commit hooks
- `git ... skip.*hooks` - Attempts to skip hooks
- `git ... --no-.*hook` - Hook bypass flags
- `HUSKY=0 git ...` - Environment variable bypass
- `SKIP_HOOKS=... git ...` - Skip hooks via env var
- `git update-ref ...` - Can bypass commit hooks
- `git filter-branch ...` - Rewrites history, bypasses hooks
- `git config core.hooksPath ...` - Disables hooks by changing path

### Pre-commit Guard

Runs pre-commit checks before allowing git operations:
- **Staged files check** - Before `git commit`
- **All files check** - Before `git push`

## Installation

Install via the baleen-plugins marketplace:

```bash
/plugin install git-guard@baleen-plugins
```

## How It Works

### PreToolUse Hook

1. Claude Code attempts to run a bash command containing `git`
2. Git Guard's `PreToolUse` hook is triggered
3. Hook analyzes the command for blocked patterns
4. If a blocked pattern is found, the command is rejected with an error message
5. Otherwise, the command proceeds normally

### Error Messages

When a command is blocked, you'll see:

```
[ERROR] --no-verify is not allowed in this repository
[INFO] Please use 'git commit' without --no-verify. All commits must pass quality checks.
```

## Configuration

### Enable/Disable Features

The hooks are controlled by `hooks/hooks.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash:git",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/commit-guard.sh"
          }
        ]
      }
    ]
  }
}
```

### Pre-commit Configuration

Ensure your repository has `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
```

## Usage

Once installed, Git Guard works automatically. No commands needed.

### Normal Usage

```bash
# This works normally
git commit -m "feat: add new feature"

# Pre-commit checks run automatically
```

### Blocked Usage

```bash
# This is BLOCKED
git commit --no-verify -m "skip checks"

# Error: --no-verify is not allowed in this repository
```

## Testing

Test the hooks:

```bash
# Run pre-commit checks on all files
plugins/git-guard/hooks/pre-commit-guard.sh --check

# Run pre-commit checks on staged files only
plugins/git-guard/hooks/pre-commit-guard.sh --staged
```

## Troubleshooting

**Pre-commit not running?**
- Verify pre-commit is installed: `pip install pre-commit`
- Check `.pre-commit-config.yaml` exists in your repo
- Ensure hooks are executable: `chmod +x plugins/git-guard/hooks/*.sh`

**Commands being blocked incorrectly?**
- Review `commit-guard.sh` for blocked patterns
- Check if your command matches a blocked pattern
- Modify the script if needed (customizable)

**Want to temporarily disable?**
- Remove or rename `hooks/hooks.json`
- Not recommended for production use

## Philosophy

Git Guard enforces the principle that **all code changes should pass quality checks**. By preventing hook bypasses, it maintains code quality standards and prevents "broken windows" - where one shortcut leads to more shortcuts.

## Repository

Part of the [baleen-plugins](https://github.com/baleen37/claude-plugins) collection - Claude Code plugins for automated development workflows.
