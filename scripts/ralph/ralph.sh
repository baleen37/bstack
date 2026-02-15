#!/bin/bash
set -euo pipefail

# === Configuration ===
# Load user configuration if it exists
CONFIG_FILE=".agents/ralph/config.sh"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

# Default STALE_SECONDS (24 hours) - can be overridden in config.sh
STALE_SECONDS="${STALE_SECONDS:-86400}"

# Validate and set max iterations
if [[ -n "${1:-}" ]]; then
  if ! [[ "$1" =~ ^[0-9]+$ ]]; then
    echo "Error: MAX_ITERATIONS must be a positive integer (got: '$1')" >&2
    exit 1
  fi
  MAX_ITERATIONS="$1"
else
  MAX_ITERATIONS=10
fi

# Path constants
RALPH_DIR=".ralph"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$RALPH_DIR/prd.json"
PROGRESS_FILE="$RALPH_DIR/progress.txt"
PID_FILE="$RALPH_DIR/ralph.pid"
LOG_DIR="$RALPH_DIR/logs"
LAST_BRANCH_FILE="$RALPH_DIR/.last-branch"
ARCHIVE_DIR="$RALPH_DIR/archive"

# Prompt template: check for user customization first, fall back to default
CUSTOM_PROMPT_TEMPLATE=".agents/ralph/prompts/loop.md"
if [[ -f "$CUSTOM_PROMPT_TEMPLATE" ]]; then
  PROMPT_TEMPLATE="$CUSTOM_PROMPT_TEMPLATE"
else
  PROMPT_TEMPLATE="$SCRIPT_DIR/prompt.md"
fi

# Guardrails file stores lessons learned and patterns discovered during iterations
GUARDRAILS_FILE="$RALPH_DIR/guardrails.md"
# Activity log tracks iteration timestamps and completion status
ACTIVITY_LOG="$RALPH_DIR/activity.log"
# Errors log records iteration failures and error details
ERRORS_LOG="$RALPH_DIR/errors.log"

# === Validation ===
if [[ ! -f "$PRD_FILE" ]]; then
  echo "Error: $PRD_FILE not found. Run /ralph-init first." >&2
  exit 1
fi

if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
  echo "Error: prompt template not found at $PROMPT_TEMPLATE" >&2
  exit 1
fi

# Validate prd.json is valid JSON and has required fields
validate_prd() {
  if ! jq empty "$PRD_FILE" 2>/dev/null; then
    echo "Error: prd.json is not valid JSON" >&2
    return 1
  fi

  local required_fields=("project" "userStories")
  for field in "${required_fields[@]}"; do
    if ! jq -e ".$field" "$PRD_FILE" >/dev/null 2>&1; then
      echo "Error: prd.json missing required field: $field" >&2
      return 1
    fi
  done

  if ! jq -e '.userStories | type == "array"' "$PRD_FILE" >/dev/null 2>&1; then
    echo "Error: prd.json userStories must be an array" >&2
    return 1
  fi

  # Validate each user story has required fields
  local story_required_fields=("id" "title" "description" "acceptanceCriteria" "priority" "status" "startedAt" "completedAt" "passes")
  local story_count
  story_count=$(jq -r '.userStories | length' "$PRD_FILE")

  for ((i=0; i<story_count; i++)); do
    for field in "${story_required_fields[@]}"; do
      if ! jq -e ".userStories[$i] | has(\"$field\")" "$PRD_FILE" >/dev/null 2>&1; then
        echo "Error: user story at index $i missing required field: $field" >&2
        return 1
      fi
    done

    # Validate status enum values
    local status
    status=$(jq -r ".userStories[$i].status" "$PRD_FILE")
    if [[ "$status" != "open" ]] && [[ "$status" != "in_progress" ]] && [[ "$status" != "done" ]]; then
      echo "Error: user story at index $i has invalid status: '$status' (must be 'open', 'in_progress', or 'done')" >&2
      return 1
    fi
  done
}

if ! validate_prd; then
  exit 1
fi

# === Helper functions ===

# Ensure we're on the correct branch
ensure_branch() {
  local target_branch="$1"
  [[ "$target_branch" == "null" || -z "$target_branch" ]] && return 0

  local current_branch
  current_branch=$(git branch --show-current)
  [[ "$current_branch" == "$target_branch" ]] && return 0

  if git show-ref --verify --quiet "refs/heads/$target_branch"; then
    git checkout "$target_branch"
  else
    git checkout -b "$target_branch"
  fi
}

# Archive previous run data
archive_previous_run() {
  local branch_to_archive="$1"
  local archive_date
  archive_date=$(date +"%Y-%m-%d")

  # Remove 'ralph/' prefix from branch name for archive directory
  local feature_name="${branch_to_archive#ralph/}"
  local archive_path="$ARCHIVE_DIR/${archive_date}-${feature_name}"

  # If archive directory already exists, append timestamp
  if [[ -d "$archive_path" ]]; then
    local timestamp
    timestamp=$(date +"%H%M%S")
    archive_path="${archive_path}-${timestamp}"
  fi

  # Create archive directory
  mkdir -p "$archive_path"

  # Archive state files
  if [[ -f "$PRD_FILE" ]]; then
    cp "$PRD_FILE" "$archive_path/"
  fi

  if [[ -f "$PROGRESS_FILE" ]]; then
    cp "$PROGRESS_FILE" "$archive_path/"
  fi

  if [[ -f "$GUARDRAILS_FILE" ]]; then
    cp "$GUARDRAILS_FILE" "$archive_path/"
  fi

  if [[ -f "$ACTIVITY_LOG" ]]; then
    cp "$ACTIVITY_LOG" "$archive_path/"
  fi

  if [[ -f "$ERRORS_LOG" ]]; then
    cp "$ERRORS_LOG" "$archive_path/"
  fi

  echo "Archived previous run (branch: $branch_to_archive) to $archive_path"
}

# Reset progress.txt to initial state
reset_progress_file() {
  cat > "$PROGRESS_FILE" <<EOF
# Ralph Progress Log
Started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Codebase Patterns
(No patterns discovered yet)

---
EOF
}

# Ensure progress.txt has proper structure
ensure_progress_file() {
  if [[ ! -f "$PROGRESS_FILE" ]]; then
    reset_progress_file
  elif ! grep -q "# Ralph Progress Log" "$PROGRESS_FILE"; then
    echo "Warning: progress.txt missing header, re-initializing" >&2
    mv "$PROGRESS_FILE" "${PROGRESS_FILE}.bak"
    reset_progress_file
  fi
}

# Template for guardrails.md content
get_guardrails_template() {
  cat <<'EOF'
# Ralph Guardrails

Lessons learned and patterns discovered during Ralph loop iterations.

## Lessons Learned
(No lessons recorded yet)

## Patterns Discovered
(No patterns discovered yet)

EOF
}

# Ensure guardrails.md has proper structure
ensure_guardrails_file() {
  if [[ ! -f "$GUARDRAILS_FILE" ]]; then
    get_guardrails_template > "$GUARDRAILS_FILE"
  elif ! grep -q "# Ralph Guardrails" "$GUARDRAILS_FILE"; then
    echo "Warning: guardrails.md missing header, re-initializing" >&2
    mv "$GUARDRAILS_FILE" "${GUARDRAILS_FILE}.bak"
    get_guardrails_template > "$GUARDRAILS_FILE"
  fi
}

# Show progress summary
show_progress_summary() {
  [[ ! -f "$PRD_FILE" ]] && return

  local total completed pending
  total=$(jq -r '.userStories | length' "$PRD_FILE")
  completed=$(jq -r '[.userStories[] | select(.status == "done")] | length' "$PRD_FILE")
  pending=$((total - completed))

  echo ""
  echo "=== Progress: $completed/$total stories completed, $pending pending ==="
  echo ""
}

# === Main initialization ===

# Read PRD data once
PRD_DATA=$(cat "$PRD_FILE")
BRANCH_NAME=$(echo "$PRD_DATA" | jq -r '.branchName')

# Check if we need to archive previous run
if [[ -f "$LAST_BRANCH_FILE" ]]; then
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE")
  if [[ "$BRANCH_NAME" != "null" ]] && [[ -n "$BRANCH_NAME" ]] && [[ "$BRANCH_NAME" != "$LAST_BRANCH" ]]; then
    archive_previous_run "$LAST_BRANCH"
    reset_progress_file
  fi
fi

# Update .last-branch with current branch
echo "$BRANCH_NAME" > "$LAST_BRANCH_FILE"

# Ensure we're on the correct branch
ensure_branch "$BRANCH_NAME"

# Ensure state files exist
ensure_progress_file
ensure_guardrails_file

# Ensure log files exist (create empty if not)
touch "$ACTIVITY_LOG" 2>/dev/null || true
touch "$ERRORS_LOG" 2>/dev/null || true

# === Check for existing loop ===
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Error: Ralph loop already running (PID $OLD_PID). Run /cancel-ralph first." >&2
    exit 1
  fi
  rm -f "$PID_FILE"
fi

# === Create log directory ===
mkdir -p "$LOG_DIR"

# === Setup cleanup handlers ===
cleanup() {
  local exit_code=$?
  rm -f "$PID_FILE"
  if [[ $exit_code -ne 0 ]]; then
    echo "Ralph loop terminated with exit code $exit_code" >&2
    echo "Log directory: $LOG_DIR" >&2
  fi
}

trap cleanup EXIT
trap 'echo "Received SIGINT, cleaning up..."; exit 130' INT
trap 'echo "Received SIGTERM, cleaning up..."; exit 143' TERM

# === Record PID ===
echo $$ > "$PID_FILE"

# === Main loop ===
echo "Ralph loop started: max $MAX_ITERATIONS iterations"
echo ""

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo "=== Ralph iteration $i/$MAX_ITERATIONS ==="

  # Build prompt from template
  PROMPT=$(sed "s/{{ITERATION}}/$i/g; s/{{MAX}}/$MAX_ITERATIONS/g" "$PROMPT_TEMPLATE")

  # Log file for this iteration
  ITERATION_LOG="$LOG_DIR/iteration-$i.log"

  # Track iteration start time
  iteration_start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Run fresh Claude instance
  echo "Starting iteration $i at $(date)" > "$ITERATION_LOG"
  if ! OUTPUT=$(echo "$PROMPT" | claude --print --dangerously-skip-permissions 2>&1 | tee -a "$ITERATION_LOG"); then
    exit_code=$?
    iteration_end=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "Warning: Claude command failed with exit code $exit_code" >&2
    echo "Check log: $ITERATION_LOG" >&2
    # Log error to errors.log
    echo "${iteration_end} - Iteration $i failed with exit code ${exit_code}" >> "$ERRORS_LOG"
    # Continue on transient errors (exit code 1), abort on fatal errors (> 1)
    if [[ $exit_code -gt 1 ]]; then
      # Log activity before exiting
      echo "${iteration_end} - Iteration $i: START=${iteration_start}, END=${iteration_end}, STATUS=FATAL_ERROR" >> "$ACTIVITY_LOG"
      exit $exit_code
    fi
    # Log failed iteration to activity
    echo "${iteration_end} - Iteration $i: START=${iteration_start}, END=${iteration_end}, STATUS=ERROR" >> "$ACTIVITY_LOG"
  else
    # Track iteration end time on success
    iteration_end=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    # Log successful iteration to activity
    echo "${iteration_end} - Iteration $i: START=${iteration_start}, END=${iteration_end}, STATUS=SUCCESS" >> "$ACTIVITY_LOG"
  fi
  echo "Finished iteration $i at $(date)" >> "$ITERATION_LOG"

  # Check for completion promise
  if echo "$OUTPUT" | grep -q '<promise>COMPLETE</promise>'; then
    echo ""
    echo "=== Ralph completed at iteration $i ==="
    show_progress_summary
    exit 0
  fi

  echo ""
  echo "--- Iteration $i finished, continuing... ---"
  show_progress_summary

  # Sleep to prevent API rate limiting
  sleep 2
done

echo "=== Ralph reached max iterations ($MAX_ITERATIONS) ==="
exit 1
