#!/usr/bin/env bash
set -euo pipefail

# preflight-check.sh - Pre-push checks: BEHIND, conflicts, branch protection (advisory)
# Usage: preflight-check.sh [base-branch]
#
# Exit codes:
#   0 - All blocking checks passed (may have advisory warnings)
#   1 - Blocking issue found (BEHIND or conflict)
#   2 - Environment error (not a git repo, gh not authenticated, etc.)

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: Not in a git repository" >&2
  exit 2
fi

resolve_base_branch "${1:-}"

if ! git fetch origin "$BASE" >/dev/null 2>&1; then
  echo "ERROR: Failed to fetch origin/$BASE" >&2
  echo "  - Check if remote 'origin' exists: git remote -v" >&2
  echo "  - Check if branch '$BASE' exists on remote" >&2
  exit 2
fi

# --- Check 1: BEHIND ---
BEHIND_COUNT=$(git rev-list HEAD..origin/"$BASE" --count 2>/dev/null || echo "0")

# --- Check 2: Conflicts ---
CONFLICT_FOUND=0
if ! MERGE_OUTPUT=$(git merge-tree --write-tree HEAD "origin/$BASE" 2>&1); then
  CONFLICT_FOUND=1
fi

if [[ "$BEHIND_COUNT" -gt 0 ]]; then
  echo "ERROR: Branch is $BEHIND_COUNT commit(s) behind origin/$BASE" >&2
  echo "  Sync with base before pushing:" >&2
  echo "    git fetch origin $BASE && git merge origin/$BASE" >&2
  if [[ "$CONFLICT_FOUND" -eq 1 ]]; then
    echo "ERROR: Conflicts detected with origin/$BASE" >&2
    echo "  Resolve conflicts after syncing:" >&2
    if echo "$MERGE_OUTPUT" | grep -q "CONFLICT"; then
      echo "Conflicts:" >&2
      echo "$MERGE_OUTPUT" | grep "CONFLICT" | sed 's/^/  - /' >&2
    fi
  fi
  exit 1
fi

if [[ "$CONFLICT_FOUND" -eq 1 ]]; then
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
fi

# --- Check 3: Branch protection (advisory only) ---
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [[ -n "$REPO" ]]; then
  PROTECTION=$(gh api "repos/$REPO/branches/$BASE/protection" 2>/dev/null || true)
  if [[ -n "$PROTECTION" ]]; then
    REQUIRED_REVIEWERS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0' 2>/dev/null || echo "0")
    REQUIRED_CHECKS=$(echo "$PROTECTION" | jq -r '.required_status_checks.contexts // [] | length' 2>/dev/null || echo "0")
    if [[ "$REQUIRED_REVIEWERS" -gt 0 || "$REQUIRED_CHECKS" -gt 0 ]]; then
      echo "INFO: Branch protection on $BASE:"
      if [[ "$REQUIRED_REVIEWERS" -gt 0 ]]; then
        echo "  - Required approvals: $REQUIRED_REVIEWERS"
      fi
      if [[ "$REQUIRED_CHECKS" -gt 0 ]]; then
        echo "  - Required CI checks: $REQUIRED_CHECKS"
        echo "$PROTECTION" | jq -r '.required_status_checks.contexts[]' 2>/dev/null | sed 's/^/    - /' || true
      fi
    fi
  fi
fi

echo "OK: Pre-flight checks passed"
echo "  - Branch is up to date with origin/$BASE"
echo "  - No merge conflicts detected"
exit 0
