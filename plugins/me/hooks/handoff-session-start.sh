#!/bin/bash
set -euo pipefail

# SessionStart hook for handoff plugin
# Notifies user about recent handoffs (within 5 minutes) that haven't been loaded

HANDOFF_DIR="$HOME/.claude/handoffs"
PROJECT_PATH="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Check if handoffs directory exists
if [ ! -d "$HANDOFF_DIR" ]; then
  exit 0
fi

# Find recent handoffs for current project (within 5 minutes, not loaded)
FIVE_MIN_AGO=$(date -u -d '5 minutes ago' +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
              python3 -c "from datetime import datetime, timedelta; print((datetime.utcnow() - timedelta(minutes=5)).strftime('%Y-%m-%dT%H:%M:%SZ'))")

found_handoff=false
handoff_summary=""

for file in "$HANDOFF_DIR"/*.json; do
  [ -f "$file" ] 2>/dev/null || continue

  # Check if handoff is for current project
  handoff_project=$(jq -r '.project_path // empty' "$file" 2>/dev/null || true)
  if [ "$handoff_project" != "$PROJECT_PATH" ]; then
    continue
  fi

  # Check if already loaded
  loaded_at=$(jq -r '.loaded_at // empty' "$file" 2>/dev/null || true)
  if [ -n "$loaded_at" ]; then
    continue
  fi

  # Check if created within 5 minutes
  created_at=$(jq -r '.created_at // empty' "$file" 2>/dev/null || true)
  if [ -z "$created_at" ]; then
    continue
  fi

  # Compare timestamps (requires GNU date or Python)
  if python3 -c "from datetime import datetime; d1=datetime.fromisoformat('$created_at'.replace('Z', '+00:00')); d2=datetime.fromisoformat('$FIVE_MIN_AGO'.replace('Z', '+00:00')); exit(0 if d1 >= d2 else 1)" 2>/dev/null; then
    found_handoff=true
    handoff_summary=$(jq -r '.summary // empty' "$file" 2>/dev/null || true)
    break
  fi
done

if [ "$found_handoff" = true ]; then
  echo "Handoff: Recent handoff found. Use /pickup to resume: $handoff_summary" >&2
  exit 0
fi

exit 0
