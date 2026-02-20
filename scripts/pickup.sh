#!/bin/bash
set -euo pipefail

# Pickup Script
# Loads a handoff session and displays all referenced context

HANDOFF_DIR="$HOME/.claude/handoffs"
PROJECT_PATH="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Function to display handoff info
display_handoff() {
  local handoff_file="$1"

  # Extract fields
  local id
  id=$(jq -r '.id' "$handoff_file")
  local created_at
  created_at=$(jq -r '.created_at' "$handoff_file")
  local project_name
  project_name=$(jq -r '.project_name' "$handoff_file")
  local branch
  branch=$(jq -r '.branch' "$handoff_file")
  local summary
  summary=$(jq -r '.summary' "$handoff_file")
  local loaded_at
  loaded_at=$(jq -r '.loaded_at // "null"' "$handoff_file")

  # Display header
  echo "Session restored from handoff"
  echo ""
  echo "ID: $id"
  echo "Created: ${created_at/T / } UTC"
  if [ "$loaded_at" != "null" ]; then
    echo "Loaded: ${loaded_at/T / } UTC"
  fi
  echo "Project: $project_name ($branch)"
  echo ""

  # Display summary
  echo "Summary:"
  echo "$summary"
  echo ""


  # Display references
  local plan_path
  plan_path=$(jq -r '.references.plan_path // empty' "$handoff_file")
  local tasks_session_id
  tasks_session_id=$(jq -r '.references.tasks_session_id // empty' "$handoff_file")
  local source_session_id
  source_session_id=$(jq -r '.source_session_id // empty' "$handoff_file")

  if [ -n "$plan_path" ] || [ -n "$tasks_session_id" ] || [ -n "$source_session_id" ]; then
    echo "References:"
    [ -n "$plan_path" ] && echo "  Plan: $plan_path"
    [ -n "$tasks_session_id" ] && echo "  Tasks Session: $tasks_session_id"
    [ -n "$source_session_id" ] && echo "  Source Session: $source_session_id"
  fi

  # Load and display plan if exists
  if [ -n "$plan_path" ]; then
    # Expand ~ to $HOME
    local expanded_path="${plan_path/#\~/$HOME}"

    if [ -f "$expanded_path" ]; then
      echo ""
      echo "---"
      echo ""
      echo "### Referenced Plan"
      cat "$expanded_path"
    else
      echo ""
      echo "Warning: Referenced plan not found: $plan_path"
    fi
  fi

  # Load and display tasks if exists
  if [ -n "$tasks_session_id" ]; then
    local tasks_state="$HOME/.claude/tasks/${tasks_session_id}/state.json"

    if [ -f "$tasks_state" ]; then
      echo ""
      echo "---"
      echo ""
      echo "### Tasks Session"
      echo "Session: $tasks_session_id"
      echo ""
      jq -r '.tasks[] | "[\(.status)] \(.subject)"' "$tasks_state" 2>/dev/null || echo "No tasks found"
    else
      echo ""
      echo "Warning: Tasks session not found: $tasks_session_id"
    fi
  fi

  # Display source session info
  if [ -n "$source_session_id" ]; then
    echo ""
    echo "---"
    echo ""
    echo "### Source Session"
    echo "Session ID: $source_session_id"
    echo "(Note: Use conversation-memory plugin to search for this session)"
  fi
}

# Check if handoffs directory exists
if [ ! -d "$HANDOFF_DIR" ]; then
  echo "No handoffs directory found."
  echo ""
  echo "Use /handoff to create a handoff for this session."
  exit 0
fi

# Check if UUID argument provided
if [ $# -gt 0 ]; then
  # Load specific handoff by UUID
  UUID="$1"
  HANDOFF_FILE="$HANDOFF_DIR/${UUID}.json"

  if [ ! -f "$HANDOFF_FILE" ]; then
    echo "Handoff not found: $UUID"
    exit 1
  fi

  # Check project path
  HANDOFF_PROJECT=$(jq -r '.project_path // empty' "$HANDOFF_FILE")
  if [ "$HANDOFF_PROJECT" != "$PROJECT_PATH" ]; then
    echo "Warning: Handoff is from a different project."
    echo "  Handoff project: $HANDOFF_PROJECT"
    echo "  Current project: $PROJECT_PATH"
    echo ""
  fi

  # Display handoff
  display_handoff "$HANDOFF_FILE"

  # Update loaded_at
  LOADED_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq --arg ts "$LOADED_TIME" '.loaded_at = $ts' "$HANDOFF_FILE" > "$HANDOFF_FILE.tmp"
  mv "$HANDOFF_FILE.tmp" "$HANDOFF_FILE"

else
  # Find most recent unloaded handoff for current project
  HANDOFF_FILE=$(find "$HANDOFF_DIR" -name "*.json" -type f -exec jq -r 'select(.project_path == "'"$PROJECT_PATH"'") | select(.loaded_at == null) | .id + " " + .created_at' {} \; 2>/dev/null | sort -k2 -r | head -1 | cut -d' ' -f1)

  if [ -z "$HANDOFF_FILE" ]; then
    echo "No unloaded handoffs found for current project."
    exit 0
  fi

  HANDOFF_FILE="$HANDOFF_DIR/${HANDOFF_FILE}.json"

  # Display handoff
  display_handoff "$HANDOFF_FILE"

  # Update loaded_at
  LOADED_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  jq --arg ts "$LOADED_TIME" '.loaded_at = $ts' "$HANDOFF_FILE" > "$HANDOFF_FILE.tmp"
  mv "$HANDOFF_FILE.tmp" "$HANDOFF_FILE"
fi
