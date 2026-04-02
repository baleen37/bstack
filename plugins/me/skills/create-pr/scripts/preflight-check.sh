#!/usr/bin/env bash
set -euo pipefail

# preflight-check.sh - Pre-push checks + auto-sync if behind
# Exit: 0=ready, 1=blocking (conflicts/push fail), 2=env error

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
require_git_repo
resolve_base_branch "${1:-}"

git fetch origin "$BASE" >/dev/null 2>&1 || { echo "ERROR: Failed to fetch origin/$BASE" >&2; exit 2; }

BEHIND=$(git rev-list HEAD..origin/"$BASE" --count 2>/dev/null || echo "0")

if [[ "$BEHIND" -gt 0 ]]; then
  echo "Behind by $BEHIND commit(s) — syncing with origin/$BASE..."
  if ! git merge "origin/$BASE" --no-edit; then
    echo "Merge conflicts:" >&2
    git diff --name-only --diff-filter=U | sed 's/^/  /' >&2
    exit 1
  fi
  git push || { echo "Push failed" >&2; exit 1; }
  echo "Synced and pushed"
fi

# Check for conflicts with latest base (post-sync or if already up-to-date)
if ! git merge-tree --write-tree HEAD "origin/$BASE" >/dev/null 2>&1; then
  echo "ERROR: Conflicts detected with origin/$BASE" >&2
  exit 1
fi

echo "OK: Pre-flight passed"
