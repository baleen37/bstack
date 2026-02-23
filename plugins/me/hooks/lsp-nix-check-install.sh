#!/usr/bin/env bash
# Auto-install nil if not found

set -euo pipefail

if command -v nil &>/dev/null; then
  echo "[lsp-nix] nil already installed"
  exit 0
fi

echo "[lsp-nix] Installing nil..."
if cargo install --git https://github.com/oxalica/nil nil &>/dev/null; then
  echo "[lsp-nix] ✓ nil installed"
  exit 0
else
  echo "[lsp-nix] ✗ Failed to install" >&2
  exit 1
fi
