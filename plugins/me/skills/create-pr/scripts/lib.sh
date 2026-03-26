#!/usr/bin/env bash
# lib.sh - Shared utilities for create-pr scripts
# Usage: source "$(dirname "$0")/lib.sh"
#
# Exit codes:
#   2 - Cannot determine default branch

# Resolve the default branch from the first argument, or auto-detect via gh CLI.
# Exits with code 2 if the branch cannot be determined.
# Usage: resolve_base_branch "$1"
#   Sets: BASE (global variable)
resolve_base_branch() {
  BASE="${1:-}"
  if [[ -z "$BASE" ]]; then
    BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
  fi
  if [[ -z "$BASE" ]]; then
    echo "ERROR: Cannot determine default branch" >&2
    echo "  - Pass base branch explicitly: $0 <base-branch>" >&2
    echo "  - Or ensure 'gh' CLI is authenticated" >&2
    exit 2
  fi
}
