#!/usr/bin/env bash
set -euo pipefail

# sync-with-base.sh - Sync current PR branch with default/base branch
# Usage: sync-with-base.sh [base-branch]
#
# Exit codes:
#   0 - Sync completed and pushed
#   1 - Conflicts detected or push failed
#   2 - Error (missing base branch, git errors, etc.)

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
  if [[ -z "$BASE" ]]; then
    echo "ERROR: Cannot determine default branch" >&2
    echo "  - Pass base branch explicitly: $0 <base-branch>" >&2
    echo "  - Or ensure 'gh' CLI is authenticated" >&2
    exit 2
  fi
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: Not in a git repository" >&2
  exit 2
fi

echo "Fetching origin/$BASE..."
if ! git fetch origin "$BASE"; then
  echo "ERROR: Failed to fetch origin/$BASE" >&2
  exit 2
fi

echo "Merging origin/$BASE into current branch..."
if ! git merge "origin/$BASE" --no-edit; then
  echo ""
  echo "✗ Merge failed - conflicts detected"
  echo "Files with conflicts:"
  git diff --name-only --diff-filter=U | sed 's/^/  - /'
  echo ""
  echo "Resolution steps:"
  echo "  1. Resolve conflicts in listed files"
  echo "  2. git add <files>"
  echo "  3. git commit"
  echo "  4. git push"
  exit 1
fi

echo "Pushing synced branch..."
if ! git push; then
  echo "ERROR: Push failed" >&2
  exit 1
fi

echo "✓ Branch synced with origin/$BASE and pushed"
exit 0
