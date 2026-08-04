#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

bash "${SCRIPT_DIR}/sync-codex-artifacts.sh"

cd "${PROJECT_ROOT}"

git diff --exit-code -- \
  .agents/plugins/marketplace.json \
  'plugins/*/.codex-plugin/plugin.json'

untracked_artifacts="$(
  git ls-files --others --exclude-standard -- \
    .agents/plugins/marketplace.json \
    'plugins/*/.codex-plugin/plugin.json'
)"

if [ -n "${untracked_artifacts}" ]; then
  echo "Untracked Codex artifacts found:" >&2
  echo "${untracked_artifacts}" >&2
  exit 1
fi
