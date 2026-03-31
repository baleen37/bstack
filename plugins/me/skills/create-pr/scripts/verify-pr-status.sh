#!/usr/bin/env bash
set -euo pipefail

# verify-pr-status.sh (read-only)
# Exit 0: merge-ready | Exit 1: action required | Exit 2: pending/CI running

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
resolve_base_branch "${1:-}"

# Single API call — fetch all needed fields at once
PR=$(gh pr view --json url,state,mergeable,mergeStateStatus,statusCheckRollup)
URL=$(jq -r .url <<<"$PR")
PR_STATE=$(jq -r .state <<<"$PR")
STATE=$(jq -r .mergeStateStatus <<<"$PR")
MERGEABLE=$(jq -r .mergeable <<<"$PR")

[[ "$PR_STATE" == "MERGED" ]] && { echo "✓ Merged: $URL"; exit 0; }
[[ "$PR_STATE" == "CLOSED" ]] && { echo "✗ Closed: $URL" >&2; exit 1; }

case "$STATE" in
  CLEAN)
    CHECKS=$(jq -r '.statusCheckRollup' <<<"$PR")
    FAILED=$(jq '[.[] | select(.isRequired==true and (.state=="FAILURE" or .state=="ERROR"))] | length' <<<"$CHECKS")
    PENDING=$(jq '[.[] | select(.isRequired==true and (.state=="PENDING" or .state=="IN_PROGRESS"))] | length' <<<"$CHECKS")

    if [[ $FAILED -gt 0 ]]; then
      echo "✗ Required CI failed: $URL" >&2
      jq -r '.[] | select(.isRequired==true and (.state=="FAILURE" or .state=="ERROR")) | "  ❌ \(.context)"' <<<"$CHECKS" >&2
      exit 1
    fi
    [[ $PENDING -gt 0 ]] && { echo "⏳ CI running: $URL" >&2; exit 2; }
    echo "✓ Merge-ready: $URL"; exit 0
    ;;
  BEHIND)   echo "✗ Behind $BASE — run: git fetch origin && git merge origin/$BASE && git push ($URL)" >&2; exit 1;;
  DIRTY)    echo "✗ Conflicts — resolve and push: $URL" >&2; exit 1;;
  *)        echo "⚠ Status $STATE ($MERGEABLE): $URL" >&2; exit 2;;
esac
