#!/usr/bin/env bash
set -euo pipefail
# preflight-check.sh — runs all checks, then announces this run's outcome up front.
# stdout carries exactly ONE terminal line; all progress/diagnostics go to stderr.
# Terminal stdout lines (exit 0):
#   NOOP: <reason>            nothing to PR
#   MERGED: <url>             already merged at current HEAD
#   READY: reuse open PR      an open PR exists; wrapper will reuse it
#   READY: create new PR      no open PR; wrapper will create one
# A leading "synced from base; " is prefixed to READY when a base sync happened.
# exit 1: blocking (conflict/dirty/push). exit 2: environment error.

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: Not a git repo" >&2; exit 2; }
BASE="${1:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")}"
[[ -n "$BASE" ]] || { echo "ERROR: Cannot determine default branch" >&2; exit 2; }
git fetch origin "$BASE" >/dev/null 2>&1 || { echo "ERROR: fetch failed" >&2; exit 2; }

SYNCED=""
if [[ $(git rev-list HEAD..origin/"$BASE" --count 2>/dev/null || echo 0) -gt 0 ]]; then
  echo "Behind base — syncing..." >&2
  if ! git merge "origin/$BASE" --no-edit >&2; then
    conflicts=$(git diff --name-only --diff-filter=U)
    if [[ -n "$conflicts" ]]; then
      echo "CONFLICT: resolve these, then re-run:" >&2
      echo "$conflicts" >&2
    else
      echo "ERROR: merge blocked; check git status --short" >&2
    fi
    exit 1
  fi
  git push -u origin HEAD >&2 || { echo "Push failed" >&2; exit 1; }
  SYNCED="synced from base; "
fi

PR_STATE=$(gh pr view --json state --jq .state 2>/dev/null || true)
PR_URL=$(gh pr view --json url --jq .url 2>/dev/null || true)
if [[ "$PR_STATE" == "MERGED" && -n "$PR_URL" ]]; then
  # Only terminal if HEAD is still the merged tip. New commits after the merge
  # mean fresh work, so fall through and let the wrapper open a new PR.
  MERGED_OID=$(gh pr view --json headRefOid --jq .headRefOid 2>/dev/null || true)
  HEAD_OID=$(git rev-parse HEAD 2>/dev/null || true)
  if [[ -z "$MERGED_OID" || "$MERGED_OID" == "$HEAD_OID" ]]; then
    echo "MERGED: $PR_URL"
    exit 0
  fi
fi

AHEAD=$(git rev-list "origin/$BASE"..HEAD --count 2>/dev/null || echo 0)
if [[ -z "$(git status --porcelain)" && "$AHEAD" -eq 0 && "$PR_STATE" != "OPEN" ]]; then
  echo "NOOP: no local changes or commits ahead of origin/$BASE"
  exit 0
fi

git merge-tree --write-tree HEAD "origin/$BASE" >/dev/null 2>&1 || { echo "ERROR: Conflicts with origin/$BASE" >&2; exit 1; }

if [[ "$PR_STATE" == "OPEN" ]]; then
  echo "READY: ${SYNCED}reuse open PR"
else
  echo "READY: ${SYNCED}create new PR"
fi
