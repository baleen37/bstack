#!/usr/bin/env bash
set -euo pipefail
# preflight-check.sh — exit 0: ready | exit 1: blocking | exit 2: env error

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: Not a git repo" >&2; exit 2; }
BASE="${1:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")}"
[[ -n "$BASE" ]] || { echo "ERROR: Cannot determine default branch" >&2; exit 2; }
git fetch origin "$BASE" >/dev/null 2>&1 || { echo "ERROR: fetch failed" >&2; exit 2; }

if [[ $(git rev-list HEAD..origin/"$BASE" --count 2>/dev/null || echo 0) -gt 0 ]]; then
  echo "Behind base — syncing..."
  if ! git merge "origin/$BASE" --no-edit; then
    conflicts=$(git diff --name-only --diff-filter=U)
    if [[ -n "$conflicts" ]]; then
      echo "$conflicts" >&2
    else
      echo "ERROR: merge blocked; check git status --short" >&2
    fi
    exit 1
  fi
  git push -u origin HEAD || { echo "Push failed" >&2; exit 1; }
fi

git merge-tree --write-tree HEAD "origin/$BASE" >/dev/null 2>&1 || { echo "ERROR: Conflicts with origin/$BASE" >&2; exit 1; }
echo "OK"
