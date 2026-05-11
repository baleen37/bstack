#!/usr/bin/env bash
set -uo pipefail
# wait-for-merge.sh — emits per-check events, then one terminal event.
# Designed for the Monitor tool: each stdout line becomes a notification.
# Terminal events (prefix indicates outcome):
#   MERGED: <url>
#   AWAITING_REVIEW: <url>
#   CI_FAILED: <url> run-id=<id>
#   CLOSED: <url>
# Exit 0 on MERGED/AWAITING_REVIEW, 1 on CI_FAILED/CLOSED/no-PR.

gh pr view --json url >/dev/null 2>&1 || { echo "ERROR: No PR" >&2; exit 1; }
URL=$(gh pr view --json url --jq .url)

case $(gh pr view --json state --jq .state) in
  MERGED) echo "MERGED: $URL"; exit 0;;
  CLOSED) echo "CLOSED: $URL"; exit 1;;
esac

prev=""
while true; do
  snap=$(gh pr checks --json name,bucket,link 2>/dev/null || echo "[]")
  cur=$(jq -r '.[] | select(.bucket!="pending") | "check: \(.name): \(.bucket)"' <<<"$snap" | sort)
  comm -13 <(echo "$prev") <(echo "$cur")
  prev=$cur

  if jq -e 'length>0 and all(.bucket!="pending")' <<<"$snap" >/dev/null 2>&1; then
    if jq -e 'any(.bucket=="fail" or .bucket=="cancel")' <<<"$snap" >/dev/null; then
      RUN_ID=$(jq -r '[.[] | select(.bucket=="fail" or .bucket=="cancel")] | .[0].link' <<<"$snap" \
        | grep -oE '[0-9]{10,}' | head -1 || true)
      echo "CI_FAILED: $URL run-id=${RUN_ID:-unknown}"
      exit 1
    fi
    break
  fi
  sleep 30
done

state=$(gh pr view --json state --jq .state 2>/dev/null || echo "")
[[ "$state" == "MERGED" ]] && { echo "MERGED: $URL"; exit 0; }
gh pr merge --squash >/dev/null 2>&1 && { echo "MERGED: $URL"; exit 0; }
echo "AWAITING_REVIEW: $URL"
exit 0
