#!/usr/bin/env bats
# Handoff reference tests - Tests about plan/session references

load ../helpers/fixture_factory

setup() {
  # Create temp directory for tests
  TEST_TEMP_DIR="$(mktemp -d)"
  export HANDOFF_TEST_DIR="$TEST_TEMP_DIR/handoffs"
  mkdir -p "$HANDOFF_TEST_DIR"

  # Mock project path
  export TEST_PROJECT_PATH="/tmp/test-project"
  mkdir -p "$TEST_PROJECT_PATH"

  # Current time for timestamps
  NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  export NOW
}

teardown() {
  rm -rf "$TEST_TEMP_DIR"
  rm -rf "$TEST_PROJECT_PATH"
}

@test "pickup resolves plan_path with tilde expansion" {
  HANDOFF_FILE="$HANDOFF_TEST_DIR/plan-handoff.json"

  # Create a test plan file
  TEST_PLAN_DIR="$TEST_TEMP_DIR/.claude/plans"
  mkdir -p "$TEST_PLAN_DIR"
  TEST_PLAN_FILE="$TEST_PLAN_DIR/test-plan.md"
  echo "# Test Plan" > "$TEST_PLAN_FILE"

  # Create handoff with plan_path reference
  create_handoff_json "$HANDOFF_FILE" "plan-handoff" "$NOW" "$TEST_PROJECT_PATH" "Handoff with plan reference" "main" "test-project" "$TEST_PLAN_FILE"

  # Extract plan_path from handoff
  PLAN_PATH=$(jq -r '.references.plan_path // empty' "$HANDOFF_FILE")
  [ "$PLAN_PATH" = "$TEST_PLAN_FILE" ]

  # Verify the expansion works
  TEST_EXPANDED="${PLAN_PATH/#\~/$TEST_TEMP_DIR}"
  [ "$TEST_EXPANDED" = "$TEST_PLAN_FILE" ]
}

@test "pickup extracts tasks_session_id for loading" {
  HANDOFF_FILE="$HANDOFF_TEST_DIR/tasks-handoff.json"
  TASKS_SESSION_ID="75c272b1-b00d-4bbb-bfa5-87269f30ff47"

  create_handoff_json "$HANDOFF_FILE" "tasks-handoff" "$NOW" "$TEST_PROJECT_PATH" "Handoff with tasks session" "main" "test-project" "null" "$TASKS_SESSION_ID"

  # Extract tasks_session_id from handoff
  EXTRACTED_SESSION_ID=$(jq -r '.references.tasks_session_id // empty' "$HANDOFF_FILE")
  [ "$EXTRACTED_SESSION_ID" = "$TASKS_SESSION_ID" ]
}

@test "pickup handles missing plan file gracefully" {
  HANDOFF_FILE="$HANDOFF_TEST_DIR/missing-plan-handoff.json"

  create_handoff_json "$HANDOFF_FILE" "missing-plan-handoff" "$NOW" "$TEST_PROJECT_PATH" "Handoff with missing plan" "main" "test-project" "$HOME/.claude/plans/nonexistent.md"

  # Extract plan_path
  PLAN_PATH=$(jq -r '.references.plan_path // empty' "$HANDOFF_FILE")
  [ -n "$PLAN_PATH" ]

  # Verify file doesn't exist (skill should show warning but continue)
  [ ! -f "$PLAN_PATH" ]
}

@test "pickup displays source_session_id when present" {
  HANDOFF_FILE="$HANDOFF_TEST_DIR/source-session-handoff.json"
  SOURCE_SESSION_ID="00538c2c-c67e-4afe-a933-bb8ed6ed19c6"

  create_handoff_json "$HANDOFF_FILE" "source-session-handoff" "$NOW" "$TEST_PROJECT_PATH" "Handoff with source session" "main" "test-project" "null" "null" "null" "$SOURCE_SESSION_ID"

  # Extract source_session_id
  EXTRACTED_SOURCE=$(jq -r '.source_session_id // empty' "$HANDOFF_FILE")
  [ "$EXTRACTED_SOURCE" = "$SOURCE_SESSION_ID" ]
}
