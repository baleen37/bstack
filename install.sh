#!/usr/bin/env bash
# install.sh — Install global Claude Code configuration
#
# Usage:
#   ./install.sh [--dry-run]
#
# This script copies global/claude-md-template.md to ~/.claude/CLAUDE.md
set -euo pipefail

# Resolve symlinks — needed when invoked via npm/bun bin symlink
SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
    link_dir="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$link_dir/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[install]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }

# --- Parse flags ---
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Show what would be done without making changes"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
    esac
done

# --- Target ---
DEST_DIR="${CLAUDE_DIR:-$HOME/.claude}"
SRC_FILE="$SCRIPT_DIR/global/claude-md-template.md"
DEST_FILE="$DEST_DIR/CLAUDE.md"

# --- Main ---
if [[ ! -f "$SRC_FILE" ]]; then
    echo "Error: $SRC_FILE not found" >&2
    exit 1
fi

if $DRY_RUN; then
    log "[DRY-RUN] cp $SRC_FILE $DEST_FILE"
else
    # Remove existing file or symlink
    rm -f "$DEST_FILE"
    mkdir -p "$DEST_DIR"
    cp "$SRC_FILE" "$DEST_FILE"
    success "Installed: $DEST_FILE"
fi
