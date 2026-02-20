#!/usr/bin/env bash
# Auto-install kotlin-language-server if not found

set -euo pipefail

if command -v kotlin-language-server &>/dev/null; then
  echo "[lsp-kotlin] kotlin-language-server already installed"
  exit 0
fi

echo "[lsp-kotlin] Installing kotlin-language-server..."
if brew install kotlin-language-server &>/dev/null; then
  echo "[lsp-kotlin] ✓ kotlin-language-server installed"
  exit 0
else
  echo "[lsp-kotlin] ✗ Failed to install" >&2
  exit 1
fi
