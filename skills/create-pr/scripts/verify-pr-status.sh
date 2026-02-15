#!/usr/bin/env bash
set -euo pipefail

# PR Status Verification (read-only)
# Usage: verify-pr-status.sh [base-branch]
#
# Exit codes:
#   0 - PR is merge-ready (CLEAN + required CI checks passed)
#   1 - Action required (BEHIND, DIRTY, failed checks, unknown state)
#   2 - Pending (required checks running, BLOCKED/UNSTABLE)

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
fi
if [[ -z "$BASE" ]]; then
  echo "ERROR: Cannot determine default branch" >&2
  echo "  - Pass base branch explicitly: $0 <base-branch>" >&2
  echo "  - Or ensure 'gh' CLI is authenticated" >&2
  exit 1
fi

PR_URL=$(gh pr view --json url -q .url)
PR_STATUS=$(gh pr view --json mergeable,mergeStateStatus)
MERGEABLE=$(echo "$PR_STATUS" | jq -r .mergeable)
STATE=$(echo "$PR_STATUS" | jq -r .mergeStateStatus)

case "$STATE" in
  CLEAN)
    CHECKS=$(gh pr view --json statusCheckRollup -q '.statusCheckRollup')

    PENDING_REQUIRED=$(echo "$CHECKS" | jq '[.[] | select(.isRequired==true and (.state=="PENDING" or .state=="IN_PROGRESS"))] | length')
    FAILED_REQUIRED=$(echo "$CHECKS" | jq '[.[] | select(.isRequired==true and (.state=="FAILURE" or .state=="ERROR"))] | length')

    if [[ $FAILED_REQUIRED -gt 0 ]]; then
      echo ""
      echo "✗ Required CI checks failed"
      echo "$CHECKS" | jq -r '.[] | select(.isRequired==true and (.state=="FAILURE" or .state=="ERROR")) | "  - ❌ \(.context): \(.state)"'
      echo ""
      echo "Fix CI failures before merge"
      echo "Monitor: gh pr checks $PR_URL"
      exit 1
    fi

    if [[ $PENDING_REQUIRED -gt 0 ]]; then
      echo ""
      echo "⚠ PR status: CLEAN but required CI checks still running"
      echo "$CHECKS" | jq -r '.[] | select(.isRequired==true and (.state=="PENDING" or .state=="IN_PROGRESS")) | "  - ⏳ \(.context): \(.state)"'
      echo ""
      echo "Cannot confirm merge-ready until CI completes"
      echo "Monitor: gh pr checks $PR_URL"
      echo "URL: $PR_URL"
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
    echo "✗ PR branch is behind $BASE"
    echo "  - Mergeable: $MERGEABLE"
    echo "  - Sync required before merge"
    echo "  - Run: ${CLAUDE_PLUGIN_ROOT:-<CLAUDE_PLUGIN_ROOT>}/skills/create-pr/scripts/sync-with-base.sh"
    echo "  - Then re-run: ${CLAUDE_PLUGIN_ROOT:-<CLAUDE_PLUGIN_ROOT>}/skills/create-pr/scripts/verify-pr-status.sh"
    echo "  - URL: $PR_URL"
    exit 1
    ;;

  DIRTY)
    echo ""
    echo "✗ PR has conflicts"
    echo "  - Mergeable: $MERGEABLE"
    echo "  - Resolve conflicts manually and push"
    echo "  - URL: $PR_URL"
    exit 1
    ;;

  BLOCKED|UNSTABLE)
    echo ""
    echo "⚠ PR status: $STATE"
    echo "  - Mergeable: $MERGEABLE"
    echo "  - This may resolve automatically as CI completes"
    echo "  - Check status: gh pr view"
    echo "  - URL: $PR_URL"
    exit 2
    ;;

  *)
    echo ""
    echo "⚠ Unknown status: $STATE"
    echo "  - Mergeable: $MERGEABLE"
    echo "  - Check manually: $PR_URL"
    exit 1
    ;;
esac
