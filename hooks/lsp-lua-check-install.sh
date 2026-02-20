#!/usr/bin/env bash
# Auto-install lua-language-server if not found

set -euo pipefail

if command -v lua-language-server &>/dev/null; then
  echo "[lsp-lua] lua-language-server already installed"
  exit 0
fi

echo "[lsp-lua] Installing lua-language-server..."
if brew install lua-language-server &>/dev/null; then
  echo "[lsp-lua] ✓ lua-language-server installed"
  exit 0
else
  echo "[lsp-lua] ✗ Failed to install" >&2
  exit 1
fi
