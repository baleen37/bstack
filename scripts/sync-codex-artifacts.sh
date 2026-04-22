#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/generate-codex-plugin-manifests.sh"
bash "${SCRIPT_DIR}/generate-codex-marketplace.sh"
