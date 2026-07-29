#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEFAULT_PACKAGE_DIR="${SCRIPT_DIR}/../plugins/knowledge-base"
PACKAGE_DIR="$(cd "${1:-$DEFAULT_PACKAGE_DIR}" && pwd -P)"
PROJECT_ROOT="$(git -C "$PACKAGE_DIR" rev-parse --show-toplevel)"

case "$PACKAGE_DIR" in
  "$PROJECT_ROOT"/*) ;;
  *)
    echo "Package directory must be inside its Git worktree: $PACKAGE_DIR" >&2
    exit 1
    ;;
esac

if [[ ! -f "$PACKAGE_DIR/package.json" ]]; then
  echo "Package manifest not found: $PACKAGE_DIR/package.json" >&2
  exit 1
fi

RELATIVE_PACKAGE="${PACKAGE_DIR#"$PROJECT_ROOT"/}"
DIST_PATH="${RELATIVE_PACKAGE}/dist"
rm -rf "$PACKAGE_DIR/dist"
bun run --cwd "$PACKAGE_DIR" build
git -C "$PROJECT_ROOT" diff --exit-code -- "$DIST_PATH"

UNTRACKED="$(git -C "$PROJECT_ROOT" ls-files --others --exclude-standard -- "$DIST_PATH")"
if [[ -n "$UNTRACKED" ]]; then
  echo "Generated dist files missing from Git:" >&2
  echo "$UNTRACKED" >&2
  exit 1
fi
