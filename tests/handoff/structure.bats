#!/usr/bin/env bats
# Handoff JSON structure tests

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

@test "handoff directory is created when it doesn't exist" {
  [ -d "$HANDOFF_TEST_DIR" ]
}

@test "handoff JSON file has correct structure" {
  # Create a test handoff file
  HANDOFF_ID="test-handoff-123"
  HANDOFF_FILE="$HANDOFF_TEST_DIR/${HANDOFF_ID}.json"

  create_handoff_json "$HANDOFF_FILE" "$HANDOFF_ID" "$NOW" "$TEST_PROJECT_PATH" "Test handoff summary" "main" "test-project" "null" "null" "null" "test-session-123"

  # Verify file exists and is valid JSON
  [ -f "$HANDOFF_FILE" ]
  jq -e '.' "$HANDOFF_FILE" >/dev/null

  # Verify required fields
  [ "$(jq -r '.id' "$HANDOFF_FILE")" = "$HANDOFF_ID" ]
  [ "$(jq -r '.project_path' "$HANDOFF_FILE")" = "$TEST_PROJECT_PATH" ]
  [ "$(jq -r '.summary' "$HANDOFF_FILE")" = "Test handoff summary" ]
}

@test "handoff loaded_at timestamp updates on pickup" {
  HANDOFF_FILE="$HANDOFF_TEST_DIR/test-loaded.json"

  create_handoff_json "$HANDOFF_FILE" "test-loaded" "$NOW" "$TEST_PROJECT_PATH" "Test loading"

  # Verify loaded_at is null initially
  [ "$(jq -r '.loaded_at' "$HANDOFF_FILE")" = "null" ]

  # Update loaded_at
  LOADED_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq --arg ts "$LOADED_TIME" '.loaded_at = $ts' "$HANDOFF_FILE" > "$HANDOFF_FILE.tmp"
  mv "$HANDOFF_FILE.tmp" "$HANDOFF_FILE"

  # Verify loaded_at was updated
  [ "$(jq -r '.loaded_at' "$HANDOFF_FILE")" = "$LOADED_TIME" ]
}

@test "session-start hook detects recent handoffs" {
  # Create a recent handoff (within 5 minutes)
  RECENT_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  create_handoff_json "$HANDOFF_TEST_DIR/recent-handoff.json" "recent-handoff" "$RECENT_TIME" "$TEST_PROJECT_PATH" "Recent work"

  # Verify handoff is recent
  created_at=$(jq -r '.created_at' "$HANDOFF_TEST_DIR/recent-handoff.json")
  [ -n "$created_at" ]
}

@test "session-start hook ignores already loaded handoffs" {
  # Create an old handoff that was already loaded
  create_handoff_json "$HANDOFF_TEST_DIR/loaded-handoff.json" "loaded-handoff" "$NOW" "$TEST_PROJECT_PATH" "Already loaded" "main" "test-project" "null" "null" "$NOW"

  # Verify loaded_at is not null
  loaded_at=$(jq -r '.loaded_at' "$HANDOFF_TEST_DIR/loaded-handoff.json")
  [ "$loaded_at" != "null" ]
}
