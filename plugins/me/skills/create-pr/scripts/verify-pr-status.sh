#!/usr/bin/env bash
set -euo pipefail

# PR Status Verification (read-only)
# Usage: verify-pr-status.sh [base-branch]
#
# Exit codes:
#   0 - PR is merge-ready (CLEAN + required CI checks passed)
#   1 - Action required (BEHIND, DIRTY, failed checks, unknown state)
#   2 - Pending (required checks running, BLOCKED/UNSTABLE)

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

resolve_base_branch "${1:-}"

PR_URL=$(gh pr view --json url -q .url)
PR_STATUS=$(gh pr view --json mergeable,mergeStateStatus,state)
MERGEABLE=$(echo "$PR_STATUS" | jq -r .mergeable)
STATE=$(echo "$PR_STATUS" | jq -r .mergeStateStatus)
PR_STATE=$(echo "$PR_STATUS" | jq -r .state)

# Already merged or closed — nothing to fix
if [[ "$PR_STATE" == "MERGED" ]]; then
  echo ""
  echo "✓ PR already merged"
  echo "  - URL: $PR_URL"
  exit 0
fi
if [[ "$PR_STATE" == "CLOSED" ]]; then
  echo ""
  echo "✗ PR was closed without merging" >&2
  echo "  - Reopen if needed: gh pr reopen" >&2
  echo "  - URL: $PR_URL" >&2
  exit 1
fi

case "$STATE" in
  CLEAN)
    CHECKS=$(gh pr view --json statusCheckRollup -q '.statusCheckRollup')

    PENDING_REQUIRED=$(echo "$CHECKS" | jq '[.[] | select(.isRequired==true and (.state=="PENDING" or .state=="IN_PROGRESS"))] | length')
    FAILED_REQUIRED=$(echo "$CHECKS" | jq '[.[] | select(.isRequired==true and (.state=="FAILURE" or .state=="ERROR"))] | length')

    if [[ $FAILED_REQUIRED -gt 0 ]]; then
      echo ""
      echo "✗ Required CI checks failed" >&2
      echo "$CHECKS" | jq -r '.[] | select(.isRequired==true and (.state=="FAILURE" or .state=="ERROR")) | "  - ❌ \(.context): \(.state)"' >&2
      echo "" >&2
      echo "Fix CI failures before merge" >&2
      echo "Monitor: gh pr checks $PR_URL" >&2
      exit 1
    fi

    if [[ $PENDING_REQUIRED -gt 0 ]]; then
      echo "" >&2
      echo "⚠ PR status: CLEAN but required CI checks still running" >&2
      echo "$CHECKS" | jq -r '.[] | select(.isRequired==true and (.state=="PENDING" or .state=="IN_PROGRESS")) | "  - ⏳ \(.context): \(.state)"' >&2
      echo "" >&2
      echo "Cannot confirm merge-ready until CI completes" >&2
      echo "Monitor: gh pr checks $PR_URL" >&2
      echo "URL: $PR_URL" >&2
      exit 2
    fi

    echo ""
    echo "✓ PR is merge-ready"
    echo "  - Status: CLEAN"
    echo "  - Required checks: Passed"
    echo "  - URL: $PR_URL"
    exit 0
    ;;

  BEHIND)
    echo ""
    echo "✗ PR branch is behind $BASE" >&2
    echo "  - Mergeable: $MERGEABLE" >&2
    echo "  - Sync required: git fetch origin && git merge origin/$BASE && git push" >&2
    echo "  - URL: $PR_URL" >&2
    exit 1
    ;;

  DIRTY)
    echo ""
    echo "✗ PR has conflicts" >&2
    echo "  - Mergeable: $MERGEABLE" >&2
    echo "  - Resolve conflicts manually and push" >&2
    echo "  - URL: $PR_URL" >&2
    exit 1
    ;;

  BLOCKED|UNSTABLE|UNKNOWN)
    echo "" >&2
    echo "⚠ PR status: $STATE" >&2
    echo "  - Mergeable: $MERGEABLE" >&2
    echo "  - This may resolve automatically as CI completes" >&2
    echo "  - Check status: gh pr view" >&2
    echo "  - URL: $PR_URL" >&2
    exit 2
    ;;

  *)
    echo "" >&2
    echo "⚠ Unknown mergeStateStatus: $STATE" >&2
    echo "  - Mergeable: $MERGEABLE" >&2
    echo "  - Check manually: $PR_URL" >&2
    exit 1
    ;;
esac
