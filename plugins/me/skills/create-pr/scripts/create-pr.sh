#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BODY_PATH="${CREATE_PR_BODY_PATH:-/tmp/pr_body.md}"
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
  mkdir -p "$(dirname "$BODY_PATH")"
  tmp="$(mktemp "${BODY_PATH}.XXXXXX")"
  cat > "$tmp"
  mv "$tmp" "$BODY_PATH"
}

PREFLIGHT_OUTPUT=$("$SCRIPT_DIR/preflight-check.sh")
printf '%s\n' "$PREFLIGHT_OUTPUT"
PREFLIGHT_LAST=$(printf '%s\n' "$PREFLIGHT_OUTPUT" | tail -n 1)

case "$PREFLIGHT_LAST" in
  NOOP:*|MERGED:*)
    exit 0
    ;;
esac

write_body
git add -- "$@"
if git diff --cached --quiet; then
  echo "NOOP: no staged changes to commit"
  exit 0
else
  git commit -m "$MESSAGE"
fi

git push -u origin HEAD

if gh pr view --json url >/dev/null 2>&1; then
  PR_URL=$(gh pr view --json url --jq .url)
  echo "PR_EXISTS: $PR_URL"
else
  TITLE="$(git log -1 --pretty=%s)"
  gh pr create --title "$TITLE" --body-file "$BODY_PATH"
fi

if [[ "$AUTO_MERGE" -eq 1 ]]; then
  gh pr merge --auto --squash
  "$SCRIPT_DIR/wait-for-merge.sh"
fi
