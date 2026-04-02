#!/usr/bin/env bash
set -euo pipefail

# sync-with-base.sh - Sync current branch with base branch
# Exit: 0=synced+pushed, 1=conflicts/push failed, 2=env error

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
require_git_repo
resolve_base_branch "${1:-}"

git fetch origin "$BASE" || { echo "ERROR: Failed to fetch origin/$BASE" >&2; exit 2; }

if ! git merge "origin/$BASE" --no-edit; then
  echo "Merge conflicts:" >&2
  git diff --name-only --diff-filter=U | sed 's/^/  /' >&2
  exit 1
fi

git push || { echo "Push failed" >&2; exit 1; }
echo "Synced with origin/$BASE and pushed"
