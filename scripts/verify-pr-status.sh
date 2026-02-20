#!/bin/bash
set -euo pipefail

# PR Status Verification with Retry Logic
# Usage: verify-pr-status.sh <base-branch>
#
# Exit codes:
#   0 - PR is merge-ready (CLEAN + CI passed)
#   1 - Error (conflicts, CI failures, max retries exceeded)
#   2 - Pending (CI still running, BLOCKED/UNSTABLE status)

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  echo "ERROR: Base branch required" >&2
  echo "Usage: $0 <base-branch>" >&2
  exit 1
fi

MAX_RETRIES=3
RETRY_COUNT=0

# Get initial status
PR_URL=$(gh pr view --json url -q .url)
PR_STATUS=$(gh pr view --json mergeable,mergeStateStatus)
MERGEABLE=$(echo "$PR_STATUS" | jq -r .mergeable)
STATE=$(echo "$PR_STATUS" | jq -r .mergeStateStatus)

while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
  case "$STATE" in
    CLEAN)
      # CRITICAL: Check CI before declaring merge-ready
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

      # All checks passed
      echo ""
      echo "✓ PR is merge-ready"
      echo "  - Status: CLEAN"
      echo "  - Required checks: Passed"
      echo "  - URL: $PR_URL"
      exit 0
      ;;

    BEHIND)
      RETRY_COUNT=$((RETRY_COUNT + 1))
      echo ""
      echo "⟳ Branch is behind $BASE (attempt $RETRY_COUNT/$MAX_RETRIES)"

      # Update branch
      git merge origin/"$BASE" --no-edit

      if [[ $? -ne 0 ]]; then
        echo ""
        echo "✗ Merge failed - conflicts detected"
        echo ""
        echo "Files with conflicts:"
        git diff --name-only --diff-filter=U | sed 's/^/  - /'
        echo ""
        echo "Resolution steps:"
        echo "  1. Resolve conflicts in listed files"
        echo "  2. git add <files>"
        echo "  3. git commit"
        echo "  4. git push"
        echo "  5. Re-run this workflow"
        exit 1
      fi

      git push

      # REQUIRED: Re-check status after update
      echo "  Verifying updated status..."
      PR_STATUS=$(gh pr view --json mergeable,mergeStateStatus)
      MERGEABLE=$(echo "$PR_STATUS" | jq -r .mergeable)
      STATE=$(echo "$PR_STATUS" | jq -r .mergeStateStatus)
      ;;

    DIRTY)
      echo ""
      echo "✗ PR has conflicts"
      echo ""
      echo "Files with conflicts:"
      git diff --name-only --diff-filter=U | sed 's/^/  - /'
      echo ""
      echo "Resolution steps:"
      echo "  1. git fetch origin $BASE"
      echo "  2. git merge origin/$BASE"
      echo "  3. Resolve conflicts in listed files"
      echo "  4. git add <files>"
      echo "  5. git commit -m 'chore: resolve merge conflicts'"
      echo "  6. git push"
      echo ""
      echo "Then check status: gh pr view"
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
done

# Max retries exceeded
echo ""
echo "✗ PR still BEHIND after $MAX_RETRIES attempts"
echo "  - Base branch is advancing faster than updates"
echo "  - Manual intervention required"
echo "  - Try: git fetch origin $BASE && git merge origin/$BASE && git push"
echo "  - URL: $PR_URL"
exit 1
