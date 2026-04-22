#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

bash "${SCRIPT_DIR}/sync-codex-artifacts.sh"

git -C "${PROJECT_ROOT}" diff --exit-code -- \
  .agents/plugins/marketplace.json \
  plugins/autoresearch/.codex-plugin/plugin.json \
  plugins/jira/.codex-plugin/plugin.json \
  plugins/me/.codex-plugin/plugin.json \
  plugins/ralph/.codex-plugin/plugin.json
