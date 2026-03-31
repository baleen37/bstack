#!/usr/bin/env bash
set -euo pipefail

# wait-for-merge.sh
# Exit 0: merged or awaiting review | Exit 1: CI failed or closed

PR=$(gh pr view --json url,state 2>/dev/null) || { echo "ERROR: No PR for current branch" >&2; exit 1; }
URL=$(jq -r .url <<<"$PR")
STATE=$(jq -r .state <<<"$PR")

[[ "$STATE" == "MERGED" ]] && { echo "✓ Already merged: $URL"; exit 0; }
[[ "$STATE" == "CLOSED" ]] && { echo "✗ PR closed: $URL" >&2; exit 1; }

echo "Waiting for CI... $URL"

# Suppress verbose watch output — only exit code matters
if ! gh pr checks --watch > /dev/null 2>&1; then
  echo "✗ CI failed: $URL" >&2
  exit 1
fi

STATE=$(gh pr view --json state -q .state)
[[ "$STATE" == "MERGED" ]] && { echo "✓ Merged: $URL"; exit 0; }

# CI passed — try direct merge (fallback if auto-merge not active)
if gh pr merge --squash --delete-branch > /dev/null 2>&1; then
  echo "✓ Merged: $URL"
  exit 0
fi

# Merge blocked — needs review
echo "✓ CI passed, awaiting review: $URL"
exit 0
