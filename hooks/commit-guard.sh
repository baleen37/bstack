#!/usr/bin/env bash
# Git Guard - Prevents bypassing git hooks and enforces pre-commit checks
set -euo pipefail

# Get the command from stdin (Claude Code passes the command via stdin)
command=$(cat)

# Blocked patterns
declare -a BLOCKED_PATTERNS=(
  "--no-verify"
  "--no-gpg-sign"
  "skip.*hooks"
  "--no-.*hook"
  "HUSKY=0"
  "SKIP_HOOKS="
  "update-ref"
  "filter-branch"
  "config core.hooksPath"
)

# Check for blocked patterns
for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$command" | grep -qE "$pattern"; then
    echo "[ERROR] '$pattern' is not allowed in this repository" >&2
    echo "[INFO] Please use git commands without bypassing hooks. All commits must pass quality checks." >&2
    exit 1
  fi
done

# Allow the command to proceed
exit 0
