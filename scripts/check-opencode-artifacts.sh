#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

bash "${SCRIPT_DIR}/sync-opencode-artifacts.sh"

cd "${PROJECT_ROOT}"

git diff --exit-code -- .opencode

untracked_artifacts="$(
  git ls-files --others --exclude-standard -- .opencode
)"

if [ -n "${untracked_artifacts}" ]; then
  echo "Untracked OpenCode artifacts found:" >&2
  echo "${untracked_artifacts}" >&2
  exit 1
fi
