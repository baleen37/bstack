#!/usr/bin/env bash
# WorktreeCreate hook: creates worktrees under .worktrees/ directory
# Input: JSON via stdin with { name, cwd, ... }
# Output: worktree path to stdout

set -euo pipefail

INPUT=$(cat)
NAME=$(echo "$INPUT" | jq -r '.name')
CWD=$(echo "$INPUT" | jq -r '.cwd')
DIR="$CWD/.worktrees/$NAME"

mkdir -p "$CWD/.worktrees"
git -C "$CWD" worktree add -b "worktree/$NAME" "$DIR" >&2

echo "$DIR"
