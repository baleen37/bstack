#!/bin/bash
set -euo pipefail

# Handoff List Script
# Lists all handoffs for the current project

HANDOFF_DIR="$HOME/.claude/handoffs"
PROJECT_PATH="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Check if handoffs directory exists
if [ ! -d "$HANDOFF_DIR" ]; then
  echo "No handoffs directory found."
  echo ""
  echo "Use /handoff to create a handoff for this session."
  exit 0
fi

# Find handoffs for current project
HANDOFF_FILES=()
for file in "$HANDOFF_DIR"/*.json; do
  [ -f "$file" ] 2>/dev/null || continue

  # Skip invalid JSON
  if ! jq -e '.' "$file" >/dev/null 2>&1; then
    echo "Warning: Skipping invalid JSON: $(basename "$file")" >&2
    continue
  fi

  # Check project path
  handoff_project=$(jq -r '.project_path // empty' "$file" 2>/dev/null || true)
  if [ "$handoff_project" = "$PROJECT_PATH" ]; then
    HANDOFF_FILES+=("$file")
  fi
done

# Check if any handoffs found
if [ ${#HANDOFF_FILES[@]} -eq 0 ]; then
  echo "No handoffs found for: $(basename "$PROJECT_PATH")"
  echo ""
  echo "Use /handoff to create a handoff for this session."
  exit 0
fi

# Sort by created_at descending (newest first)
SORTED_HANDOFFS=$(jq -s 'sort_by(.created_at) | reverse' "${HANDOFF_FILES[@]}")
HANDOFF_COUNT=$(echo "$SORTED_HANDOFFS" | jq 'length')

# Display header
PROJECT_NAME=$(basename "$PROJECT_PATH")
echo "Handoffs for: $PROJECT_NAME ($PROJECT_PATH)"
echo ""

# Display table header
printf "%-37s %-20s %s\n" "ID" "Created" "Summary"
printf "%-37s %-20s %s\n" "-----------------------------------" "--------------------" "----------------------------------"

# Display each handoff
echo "$SORTED_HANDOFFS" | jq -r '.[] |
  "\(.id[0:37]) \t \(.created_at[0:16] | gsub("T"; " ")) \t \(.summary[0:50])"' |
  column -t -s $'\t'

echo ""
echo "$HANDOFF_COUNT handoff(s) found"
echo "Use /pickup {uuid} to restore a specific handoff"
