#!/usr/bin/env bash
# Auto-install typescript-language-server if not found

set -euo pipefail

if command -v typescript-language-server &>/dev/null; then
  echo "[lsp-typescript] typescript-language-server already installed"
  exit 0
fi

echo "[lsp-typescript] Installing typescript-language-server..."
if npm install -g typescript-language-server typescript &>/dev/null; then
  echo "[lsp-typescript] ✓ typescript-language-server installed"
  exit 0
else
  echo "[lsp-typescript] ✗ Failed to install" >&2
  exit 1
fi
