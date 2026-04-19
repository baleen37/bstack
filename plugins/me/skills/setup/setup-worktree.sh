#!/usr/bin/env bash
# WorktreeCreate hook: creates worktrees under .worktrees/ directory
# Matches gw() convention: .worktrees/{NNNNN}-{name}
# Input: JSON via stdin with { name, cwd, ... }
# Output: worktree path to stdout

set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')

# Resolve repo root (handles being called from inside a worktree)
REPO_ROOT=$(git -C "$CWD" worktree list | head -1 | awk '{print $1}')

mkdir -p "$REPO_ROOT/.worktrees"

# Sequential number prefix matching gw() convention
NEXT_NUM=$(printf "%05d" $(( $(git -C "$CWD" worktree list | tail -n +2 | wc -l | tr -d ' ') + 1 )))
DIR="$REPO_ROOT/.worktrees/${NEXT_NUM}-${NAME}"

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
