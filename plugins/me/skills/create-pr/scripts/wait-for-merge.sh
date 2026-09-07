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
# Observes only: this script never runs `gh pr merge`.

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

# Never merge from here. If auto-merge is enabled GitHub merges once checks pass;
# give it up to a minute to land before reporting.
auto=$(gh pr view --json autoMergeRequest --jq '.autoMergeRequest != null' 2>/dev/null || echo false)
for _ in 1 2 3 4 5 6; do
  [[ $(gh pr view --json state --jq .state 2>/dev/null || echo "") == "MERGED" ]] && { echo "MERGED: $URL"; exit 0; }
  [[ "$auto" == "true" ]] || break
  sleep 10
done
echo "AWAITING_REVIEW: $URL"
exit 0
