#!/usr/bin/env bash
# lib.sh - Shared utilities for create-pr scripts
# Exit codes: 2 = environment error

require_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: Not in a git repository" >&2; exit 2; }
}

# Sets BASE global. Usage: resolve_base_branch "$1"
resolve_base_branch() {
  BASE="${1:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")}"
  [[ -n "$BASE" ]] || { echo "ERROR: Cannot determine default branch (pass explicitly or auth gh)" >&2; exit 2; }
}
