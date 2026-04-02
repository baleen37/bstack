#!/usr/bin/env bash
set -euo pipefail

# wait-for-merge.sh - Exit 0: merged/awaiting review | Exit 1: CI failed/closed

PR=$(gh pr view --json url,state 2>/dev/null) || { echo "ERROR: No PR for current branch" >&2; exit 1; }
URL=$(jq -r .url <<<"$PR")
STATE=$(jq -r .state <<<"$PR")

[[ "$STATE" == "MERGED" ]] && { echo "Already merged: $URL"; exit 0; }
[[ "$STATE" == "CLOSED" ]] && { echo "PR closed: $URL" >&2; exit 1; }

echo "Waiting for CI... $URL"
if ! gh pr checks --watch > /dev/null 2>&1; then
  FAILED_RUN=$(gh pr checks --json name,link,state \
    -q '[.[] | select(.state=="FAILURE")] | .[0].link' 2>/dev/null \
    | grep -oE '[0-9]{10,}' | head -1 || true)
  echo "CI failed: $URL" >&2
  [[ -n "$FAILED_RUN" ]] && echo "  run-id: $FAILED_RUN" >&2
  exit 1
fi

STATE=$(gh pr view --json state -q .state)
[[ "$STATE" == "MERGED" ]] && { echo "Merged: $URL"; exit 0; }

gh pr merge --squash --delete-branch > /dev/null 2>&1 && { echo "Merged: $URL"; exit 0; }
echo "CI passed, awaiting review: $URL"
