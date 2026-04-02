#!/usr/bin/env bash
set -euo pipefail

# preflight-check.sh - Pre-push checks: BEHIND, conflicts
# Exit: 0=pass, 1=blocking, 2=env error

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
require_git_repo
resolve_base_branch "${1:-}"

git fetch origin "$BASE" >/dev/null 2>&1 || { echo "ERROR: Failed to fetch origin/$BASE" >&2; exit 2; }

BEHIND=$(git rev-list HEAD..origin/"$BASE" --count 2>/dev/null || echo "0")
CONFLICT=0
MERGE_OUT=$(git merge-tree --write-tree HEAD "origin/$BASE" 2>&1) || CONFLICT=1

if [[ "$BEHIND" -gt 0 ]]; then
  echo "ERROR: $BEHIND commit(s) behind origin/$BASE — sync before pushing" >&2
  [[ "$CONFLICT" -eq 1 ]] && echo "ERROR: Conflicts detected with origin/$BASE" >&2
  exit 1
fi

if [[ "$CONFLICT" -eq 1 ]]; then
  echo "ERROR: Conflicts detected with origin/$BASE" >&2
  echo "$MERGE_OUT" | grep "CONFLICT" | sed 's/^/  /' >&2 || true
  exit 1
fi

echo "OK: Pre-flight checks passed"
