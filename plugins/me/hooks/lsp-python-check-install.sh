#!/usr/bin/env bash
# Auto-install pyright if not found

set -euo pipefail

if command -v pyright &>/dev/null; then
  echo "[lsp-python] pyright already installed"
  exit 0
fi

echo "[lsp-python] Installing pyright..."
if npm install -g pyright &>/dev/null; then
  echo "[lsp-python] ✓ pyright installed"
  exit 0
else
  echo "[lsp-python] ✗ Failed to install" >&2
  exit 1
fi
