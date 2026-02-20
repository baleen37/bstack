#!/usr/bin/env bash
set -euo pipefail

# check-conflicts.sh - Check for merge conflicts between current branch and base
#
# Usage: check-conflicts.sh <base-branch>
#
# Exit codes:
#   0 - No conflicts (clean merge)
#   1 - Conflicts detected (manual resolution required)
#   2 - Error (missing base branch, git errors, etc.)

# Color codes for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check arguments
if [[ $# -ne 1 ]]; then
  echo -e "${RED}ERROR: Missing base branch argument${NC}" >&2
  echo "Usage: $0 <base-branch>" >&2
  exit 2
fi

BASE="$1"

# Verify we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo -e "${RED}ERROR: Not in a git repository${NC}" >&2
  exit 2
fi

# Fetch latest base branch
echo "Fetching origin/$BASE..."
if ! git fetch origin "$BASE" 2>/dev/null; then
  echo -e "${RED}ERROR: Failed to fetch origin/$BASE${NC}" >&2
  echo "  - Check if remote 'origin' exists: git remote -v" >&2
  echo "  - Check if branch '$BASE' exists on remote" >&2
  exit 2
fi

# Get merge base
MERGE_BASE=$(git merge-base HEAD "origin/$BASE" 2>/dev/null)
if [[ -z "$MERGE_BASE" ]]; then
  echo -e "${RED}ERROR: Cannot find common ancestor with origin/$BASE${NC}" >&2
  exit 2
fi

# Check for merge conflicts using merge-tree
echo "Checking for conflicts with origin/$BASE..."
MERGE_OUTPUT=$(git merge-tree "$MERGE_BASE" HEAD "origin/$BASE" 2>&1)
MERGE_EXIT=$?

if [[ $MERGE_EXIT -ne 0 ]]; then
  # Conflicts detected
  echo -e "${YELLOW}WARNING: Conflicts detected with origin/$BASE${NC}" >&2
  echo "" >&2

  # Try to detect whitespace-only conflicts
  DIFF_OUTPUT=$(git diff "origin/$BASE"...HEAD 2>/dev/null || echo "")

  if echo "$DIFF_OUTPUT" | grep -q "^[-+]\s*$"; then
    echo -e "${YELLOW}Note: Some conflicts may be whitespace-only${NC}" >&2
    echo "  - Consider: git merge origin/$BASE --strategy-option=ignore-space-change" >&2
  fi

  # Show conflict summary
  echo -e "${RED}Conflicts require manual resolution:${NC}" >&2
  echo "  1. git fetch origin $BASE" >&2
  echo "  2. git merge origin/$BASE" >&2
  echo "  3. Resolve conflicts in affected files" >&2
  echo "  4. git add <resolved-files>" >&2
  echo "  5. git commit" >&2
  echo "" >&2

  # Try to extract conflicting files from merge-tree output
  if echo "$MERGE_OUTPUT" | grep -q "CONFLICT"; then
    echo -e "${RED}Files with conflicts:${NC}" >&2
    echo "$MERGE_OUTPUT" | grep "CONFLICT" | sed 's/^/  - /' >&2
  fi

  exit 1
fi

# No conflicts
echo -e "${GREEN}✓ No conflicts detected${NC}"
echo "  - Current branch merges cleanly with origin/$BASE"
exit 0
