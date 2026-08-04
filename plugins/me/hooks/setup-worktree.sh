#!/usr/bin/env bash
# WorktreeCreate hook: creates worktrees under .worktrees/ directory
# Matches the wt() shell wrapper convention: .worktrees/{YYMMDD}-{name}
# Input: JSON via stdin with { name, cwd, ... }
# Output: worktree path to stdout

set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Resolve repo root (handles being called from inside a worktree)
REPO_ROOT=$(git -C "$CWD" worktree list --porcelain | sed -n 's/^worktree //p' | head -1)

mkdir -p "$REPO_ROOT/.worktrees"

# Date prefix and slash sanitizing match wt()'s _sanitize_branch
DIR="$REPO_ROOT/.worktrees/$(date +%y%m%d)-${NAME//\//-}"

if [ -d "$DIR" ]; then
  echo "Worktree already exists: $DIR" >&2
  exit 1
fi

# Find base branch
if git -C "$CWD" rev-parse --verify main >/dev/null 2>&1; then
  BASE="main"
elif git -C "$CWD" rev-parse --verify master >/dev/null 2>&1; then
  BASE="master"
else
  echo "No main or master branch found" >&2
  exit 1
fi

git -C "$CWD" worktree add -b "$NAME" "$DIR" "$BASE" >&2

echo "$DIR"
