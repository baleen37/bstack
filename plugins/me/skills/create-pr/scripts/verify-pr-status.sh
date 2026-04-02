#!/usr/bin/env bash
set -euo pipefail

# verify-pr-status.sh - Exit 0: merge-ready | Exit 1: action needed | Exit 2: pending

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
resolve_base_branch "${1:-}"

PR=$(gh pr view --json url,state,mergeable,mergeStateStatus,statusCheckRollup)
URL=$(jq -r .url <<<"$PR")
STATE=$(jq -r .state <<<"$PR")

[[ "$STATE" == "MERGED" ]] && { echo "Merged: $URL"; exit 0; }
[[ "$STATE" == "CLOSED" ]] && { echo "Closed: $URL" >&2; exit 1; }

case "$(jq -r .mergeStateStatus <<<"$PR")" in
  CLEAN)
    CHECKS=$(jq -r '.statusCheckRollup' <<<"$PR")
    FAILED=$(jq '[.[] | select(.isRequired and (.state=="FAILURE" or .state=="ERROR"))] | length' <<<"$CHECKS")
    PENDING=$(jq '[.[] | select(.isRequired and (.state=="PENDING" or .state=="IN_PROGRESS"))] | length' <<<"$CHECKS")
    [[ $FAILED -gt 0 ]] && { echo "Required CI failed: $URL" >&2; jq -r '.[] | select(.isRequired and (.state=="FAILURE" or .state=="ERROR")) | "  \(.context)"' <<<"$CHECKS" >&2; exit 1; }
    [[ $PENDING -gt 0 ]] && { echo "CI running: $URL" >&2; exit 2; }
    echo "Merge-ready: $URL"; exit 0;;
  BEHIND)  echo "Behind $BASE: $URL" >&2; exit 1;;
  DIRTY)   echo "Conflicts: $URL" >&2; exit 1;;
  *)       echo "Status $(jq -r .mergeStateStatus <<<"$PR"): $URL" >&2; exit 2;;
esac
