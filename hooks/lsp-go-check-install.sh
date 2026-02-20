#!/usr/bin/env bash
# Auto-install gopls if not found

set -euo pipefail

if command -v gopls &>/dev/null; then
  echo "[lsp-go] gopls already installed"
  exit 0
fi

echo "[lsp-go] Installing gopls..."
if go install golang.org/x/tools/gopls@latest &>/dev/null; then
  echo "[lsp-go] ✓ gopls installed"
  exit 0
else
  echo "[lsp-go] ✗ Failed to install" >&2
  exit 1
fi
