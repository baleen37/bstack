#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BODY_PATH="${CREATE_PR_BODY_PATH:-}"
AUTO_MERGE=0

usage() {
  cat >&2 <<'EOF'
Usage: printf '%s\n' '<PR body>' | create-pr.sh [--auto-merge] '<commit message>' -- <files...>
EOF
}

if [[ "${1:-}" == "--auto-merge" ]]; then
  AUTO_MERGE=1
  shift
fi

MESSAGE="${1:-}"
[[ -n "$MESSAGE" ]] || { usage; exit 2; }
shift

[[ "${1:-}" == "--" ]] || { usage; exit 2; }
shift
[[ "$#" -gt 0 ]] || { usage; exit 2; }

write_body() {
  local tmp
  if [[ -z "$BODY_PATH" ]]; then
    local body_template
    body_template="$(git rev-parse --git-path create-pr-body.XXXXXX)"
    mkdir -p "$(dirname "$body_template")"
    BODY_PATH="$(mktemp "$body_template")"
    trap 'rm -f "$BODY_PATH"' EXIT
  fi
  mkdir -p "$(dirname "$BODY_PATH")"
  tmp="$(mktemp "${BODY_PATH}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$BODY_PATH"
}

BASE="${BASE:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)}"
set +e
PREFLIGHT_OUTPUT=$("$SCRIPT_DIR/preflight-check.sh" "$BASE")
PREFLIGHT_STATUS=$?
set -e
PREFLIGHT_LAST=$(printf '%s\n' "$PREFLIGHT_OUTPUT" | tail -n 1)

case "$PREFLIGHT_LAST" in
  # Terminal already: pass it straight through as the single stdout line.
  NOOP:*|MERGED:*)
    printf '%s\n' "$PREFLIGHT_LAST"
    exit "$PREFLIGHT_STATUS"
    ;;
  READY:*)
    # Announcement only — echo to stderr so the agent knows the planned outcome,
    # while stdout stays reserved for the one final terminal prefix below.
    printf '%s\n' "$PREFLIGHT_LAST" >&2
    ;;
  *)
    # Non-terminal failure (exit 1/2): surface preflight output and stop.
    printf '%s\n' "$PREFLIGHT_OUTPUT" >&2
    exit "$PREFLIGHT_STATUS"
    ;;
esac

write_body
git add -- "$@"
if git diff --cached --quiet; then
  AHEAD=$(git rev-list "origin/$BASE"..HEAD --count 2>/dev/null || echo 0)
  if gh pr view --json url >/dev/null 2>&1; then
    :
  elif [[ "$AHEAD" -gt 0 ]]; then
    :
  else
    echo "NOOP: no staged changes or branch diff"
    exit 0
  fi
else
  git commit -m "$MESSAGE" >&2
fi

git push -u origin HEAD >&2

PR_STATE=$(gh pr view --json state --jq .state 2>/dev/null || true)
if [[ "$PR_STATE" != "OPEN" ]]; then
  TITLE="$(git log -1 --pretty=%s)"
  if ! gh pr create --title "$TITLE" --body-file "$BODY_PATH" >/dev/null; then
    PR_STATE=$(gh pr view --json state --jq .state 2>/dev/null || true)
    if [[ "$PR_STATE" != "OPEN" ]]; then
      echo "PR create failed; no existing PR found." >&2
      exit 1
    fi
  fi
fi
if [[ "$AUTO_MERGE" -eq 1 ]]; then
  # wait-for-merge.sh emits the single terminal prefix (MERGED/AWAITING_REVIEW/CI_FAILED).
  gh pr merge --auto --squash >/dev/null
  "$SCRIPT_DIR/wait-for-merge.sh"
else
  # Single terminal prefix for "PR is open and ready", whether reused or just created.
  echo "PR_EXISTS: $(gh pr view --json url --jq .url)"
fi
