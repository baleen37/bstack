#!/usr/bin/env bash
set -euo pipefail

# wait-for-merge.sh - Wait for PR CI to complete and confirm merge
# Usage: wait-for-merge.sh
#
# Assumes: PR exists for current branch, auto-merge is already enabled
#
# Exit codes:
#   0 - PR merged successfully, or CI passed and awaiting review approval
#   1 - PR closed without merge, or CI failed

PR_INFO=$(gh pr view --json url,state 2>/dev/null || true)
if [[ -z "$PR_INFO" ]]; then
  echo "ERROR: No open PR found for current branch" >&2
  echo "  - Create a PR first: gh pr create" >&2
  exit 1
fi

PR_URL=$(echo "$PR_INFO" | jq -r .url)
PR_STATE=$(echo "$PR_INFO" | jq -r .state)

if [[ "$PR_STATE" == "MERGED" ]]; then
  echo ""
  echo "✓ PR already merged"
  echo "  - URL: $PR_URL"
  exit 0
fi

if [[ "$PR_STATE" == "CLOSED" ]]; then
  echo ""
  echo "✗ PR was closed without merging" >&2
  echo "  - URL: $PR_URL" >&2
  exit 1
fi

echo "Waiting for CI checks to complete..."
echo "  - URL: $PR_URL"

# Block until all CI checks finish (pass or fail)
if ! gh pr checks --watch 2>&1; then
  echo "" >&2
  echo "✗ CI checks failed" >&2
  echo "  - Fix CI failures and push again" >&2
  echo "  - Monitor: gh pr checks $PR_URL" >&2
  exit 1
fi

# Single state check after CI completes
FINAL_STATE=$(gh pr view --json state -q .state)

if [[ "$FINAL_STATE" == "MERGED" ]]; then
  echo ""
  echo "✓ PR merged successfully"
  echo "  - URL: $PR_URL"
  exit 0
fi

if [[ "$FINAL_STATE" == "OPEN" ]]; then
  echo ""
  echo "✓ CI passed. PR awaiting review approval."
  echo "  - URL: $PR_URL"
  echo "  - Auto-merge is enabled — PR will merge after approval"
  exit 0
fi

echo "" >&2
echo "✗ PR not merged (state: $FINAL_STATE)" >&2
echo "  - URL: $PR_URL" >&2
echo "  - Check: gh pr view" >&2
exit 1
