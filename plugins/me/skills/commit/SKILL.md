---
name: commit
description: Use when the user asks to "commit", "git commit", "커밋", or runs /commit — reviews changes, stages files, and creates a single git commit
disable-model-invocation: true
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*)
---

# Commit

## Context

- Current git status: !`git status`
- Staged and unstaged changes: !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits (for style matching): !`git log --oneline -10`

## Your Task

Based on the above changes, create a single git commit.

1. **Analyze changes** — understand what changed and why
2. **Stage files** — `git add <specific-files>` (NEVER use `git add -A` or `git add .`)
3. **Commit** — use Conventional Commits format: `type(scope): description`
   - Match the style of recent commits shown above
   - Use a HEREDOC for the commit message

```bash
git commit -m "$(cat <<'EOF'
type(scope): summary

Optional body explaining why, not what.
EOF
)"
```

## Rules

- Do NOT commit files that may contain secrets (.env, credentials, tokens)
- Do NOT push to remote — commit only
- Do NOT use any other tools besides the allowed git commands
- Do NOT send any other text or messages besides tool calls
- Stage and commit in a single message using parallel tool calls where possible
