#!/bin/bash
set -euo pipefail

# Handoff Script
# Saves current session context to a handoff file

# Arguments: $1 = summary
SUMMARY="$1"

HANDOFF_DIR="$HOME/.claude/handoffs"
PROJECT_PATH="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Create handoff directory
mkdir -p "$HANDOFF_DIR"

# Get project information
if git rev-parse --git-dir >/dev/null 2>&1; then
  PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
else
  PROJECT_NAME=$(basename "$PROJECT_PATH")
  BRANCH="no-git"
fi

# Detect session references
# Check for active plan (most recent .md file in ~/.claude/plans/)
PLAN_PATH=""
if [ -d "$HOME/.claude/plans" ]; then
  PLAN_PATH=$(find "$HOME/.claude/plans" -name "*.md" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "$PLAN_PATH" ]; then
    # Convert to ~ path for portability
    PLAN_PATH="~${PLAN_PATH#$HOME}"
  fi
fi

# Check for active tasks session
TASKS_SESSION_ID=""
if [ -d "$HOME/.claude/tasks" ]; then
  TASKS_SESSION_ID=$(find "$HOME/.claude/tasks" -name "state.json" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | xargs dirname | xargs basename)
fi

# Get current session ID (if available)
SESSION_ID="${CLAUDE_SESSION_ID:-}"

# Generate UUID
if command -v uuidgen >/dev/null 2>&1; then
  UUID=$(uuidgen | tr '[:lower:]' '[:upper:]')
else
  # Fallback: generate UUID-like string
  UUID=$(od -X /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}' | tr '[:lower:]' '[:upper:]')
fi

# Current timestamp
CREATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build handoff JSON using jq
HANDOFF_FILE="$HANDOFF_DIR/$UUID.json"

# Build JSON with jq to handle null values correctly
jq -n \
  --arg id "$UUID" \
  --arg created_at "$CREATED_AT" \
  --arg project_name "$PROJECT_NAME" \
  --arg project_path "$PROJECT_PATH" \
  --arg branch "$BRANCH" \
  --arg summary "$SUMMARY" \
  --arg plan_path "${PLAN_PATH:-null}" \
  --arg tasks_session_id "${TASKS_SESSION_ID:-null}" \
  --arg source_session_id "${SESSION_ID:-null}" \
  '{
    id: $id,
    created_at: $created_at,
    loaded_at: null,
    project_name: $project_name,
    project_path: $project_path,
    branch: $branch,
    summary: $summary,
    references: {
      plan_path: (if $plan_path == "null" then null else $plan_path end),
      tasks_session_id: (if $tasks_session_id == "null" then null else $tasks_session_id end)
    },
    source_session_id: (if $source_session_id == "null" then null else $source_session_id end)
  }' > "$HANDOFF_FILE"

# Display handoff information
echo "Handoff saved successfully!"
echo ""
echo "ID: $UUID"
echo "Project: $PROJECT_NAME ($BRANCH)"
echo "Summary: $SUMMARY"
echo ""
echo "Use /pickup to restore this session, or /pickup $UUID to restore this specific handoff."
