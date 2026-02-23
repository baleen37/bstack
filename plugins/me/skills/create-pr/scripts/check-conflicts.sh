#!/usr/bin/env bash
set -euo pipefail

# check-conflicts.sh - Check for merge conflicts between current branch and base
# Usage: check-conflicts.sh [base-branch]
#
# Exit codes:
#   0 - No conflicts (clean merge)
#   1 - Conflicts detected (manual resolution required)
#   2 - Error (missing base branch, git errors, etc.)

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
fi
if [[ -z "$BASE" ]]; then
  echo "ERROR: Cannot determine default branch" >&2
  echo "  - Pass base branch explicitly: $0 <base-branch>" >&2
  echo "  - Or ensure 'gh' CLI is authenticated" >&2
  exit 2
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: Not in a git repository" >&2
  exit 2
fi

if ! git fetch origin "$BASE" >/dev/null 2>&1; then
  echo "ERROR: Failed to fetch origin/$BASE" >&2
  echo "  - Check if remote 'origin' exists: git remote -v" >&2
  echo "  - Check if branch '$BASE' exists on remote" >&2
  exit 2
fi

MERGE_BASE=$(git merge-base HEAD "origin/$BASE" 2>/dev/null || echo "")
if [[ -z "$MERGE_BASE" ]]; then
  echo "ERROR: Cannot find common ancestor with origin/$BASE" >&2
  exit 2
fi

if MERGE_OUTPUT=$(git merge-tree "$MERGE_BASE" HEAD "origin/$BASE" 2>&1); then
  echo "OK: No conflicts detected"
  echo "  - Current branch merges cleanly with origin/$BASE"
  exit 0
fi

echo "ERROR: Conflicts detected with origin/$BASE" >&2
echo "Resolution steps:" >&2
echo "  1. git fetch origin $BASE" >&2
echo "  2. git merge origin/$BASE" >&2
echo "  3. Resolve conflicts" >&2
echo "  4. git add <resolved-files>" >&2
echo "  5. git commit" >&2

if echo "$MERGE_OUTPUT" | grep -q "CONFLICT"; then
  echo "Conflicts:" >&2
  echo "$MERGE_OUTPUT" | grep "CONFLICT" | sed 's/^/  - /' >&2
fi

exit 1
