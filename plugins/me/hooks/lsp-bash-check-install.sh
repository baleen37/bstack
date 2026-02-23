#!/usr/bin/env bash
# Auto-install bash-language-server if not found

set -euo pipefail

if command -v bash-language-server &>/dev/null; then
  echo "[lsp-bash] bash-language-server already installed"
  exit 0
fi

echo "[lsp-bash] Installing bash-language-server..."
if npm install -g bash-language-server &>/dev/null; then
  echo "[lsp-bash] ✓ bash-language-server installed"
  exit 0
else
  echo "[lsp-bash] ✗ Failed to install" >&2
  exit 1
fi
