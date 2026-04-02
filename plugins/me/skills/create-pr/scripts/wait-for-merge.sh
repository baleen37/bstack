#!/usr/bin/env bash
set -euo pipefail
# wait-for-merge.sh — exit 0: merged/awaiting review | exit 1: CI failed/closed

PR=$(gh pr view --json url,state 2>/dev/null) || { echo "ERROR: No PR" >&2; exit 1; }
URL=$(jq -r .url <<<"$PR")
case $(jq -r .state <<<"$PR") in
  MERGED) echo "Merged: $URL"; exit 0;;
  CLOSED) echo "Closed: $URL" >&2; exit 1;;
esac

echo "Waiting for CI... $URL"
if ! gh pr checks --watch >/dev/null 2>&1; then
  RUN_ID=$(gh pr checks --json name,link,state \
    -q '[.[] | select(.state=="FAILURE")] | .[0].link' 2>/dev/null \
    | grep -oE '[0-9]{10,}' | head -1 || true)
  echo "CI failed: $URL" >&2
  [[ -n "$RUN_ID" ]] && echo "  run-id: $RUN_ID" >&2
  exit 1
fi

[[ $(gh pr view --json state -q .state) == "MERGED" ]] && { echo "Merged: $URL"; exit 0; }
gh pr merge --squash --delete-branch >/dev/null 2>&1 && { echo "Merged: $URL"; exit 0; }
echo "CI passed, awaiting review: $URL"
