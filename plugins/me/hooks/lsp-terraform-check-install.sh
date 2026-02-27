#!/usr/bin/env bash
# Check terraform-ls version at a pinned target without auto-installing

set -euo pipefail

TARGET_TERRAFORM_LS_VERSION="v0.38.4"

if ! command -v terraform-ls &>/dev/null; then
  echo "[lsp-terraform] terraform-ls is not installed"
  echo "[lsp-terraform] Please install manually with: go install github.com/hashicorp/terraform-ls@${TARGET_TERRAFORM_LS_VERSION}"
  exit 0
fi

if terraform-ls -v | grep -q "${TARGET_TERRAFORM_LS_VERSION}"; then
  echo "[lsp-terraform] terraform-ls ${TARGET_TERRAFORM_LS_VERSION} already installed"
  exit 0
else
  echo "[lsp-terraform] terraform-ls version mismatch"
  echo "[lsp-terraform] Expected ${TARGET_TERRAFORM_LS_VERSION}, found $(terraform-ls -v | head -n 1)"
  exit 0
fi
