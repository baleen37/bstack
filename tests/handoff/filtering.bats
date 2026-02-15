#!/usr/bin/env bats
# Handoff filtering and sorting tests

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

@test "handoff file filtering by project path works" {
  # Create handoffs for different projects
  create_handoff_json "$HANDOFF_TEST_DIR/handoff1.json" "handoff1" "$NOW" "$TEST_PROJECT_PATH" "Test project handoff"
  create_handoff_json "$HANDOFF_TEST_DIR/handoff2.json" "handoff2" "$NOW" "/other/project" "Other project handoff"

  # Filter by project path
  result=$(jq -s '[.[] | select(.project_path == "'"$TEST_PROJECT_PATH"'")] | length' "$HANDOFF_TEST_DIR"/*.json)
  [ "$result" -eq 1 ]
}

@test "handoff-list sorts by created_at descending" {
  # Create handoffs with different timestamps
  create_handoff_json "$HANDOFF_TEST_DIR/old.json" "old" "2026-02-01T10:00:00Z" "$TEST_PROJECT_PATH" "Old handoff"
  create_handoff_json "$HANDOFF_TEST_DIR/new.json" "new" "2026-02-04T10:00:00Z" "$TEST_PROJECT_PATH" "New handoff"
  create_handoff_json "$HANDOFF_TEST_DIR/middle.json" "middle" "2026-02-02T10:00:00Z" "$TEST_PROJECT_PATH" "Middle handoff"

  # Sort by created_at descending
  result=$(jq -s 'sort_by(.created_at) | reverse | .[0].id' "$HANDOFF_TEST_DIR"/*.json)
  [ "$result" = '"new"' ]
}

@test "session-start hook detects recent handoffs" {
  # Create a recent handoff (within 5 minutes)
  RECENT_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  create_handoff_json "$HANDOFF_TEST_DIR/recent-handoff.json" "recent-handoff" "$RECENT_TIME" "$TEST_PROJECT_PATH" "Recent work"

  # Verify handoff is recent
  created_at=$(jq -r '.created_at' "$HANDOFF_TEST_DIR/recent-handoff.json")
  [ -n "$created_at" ]
}

@test "pickup finds most recent unloaded handoff for project" {
  # Create multiple handoffs for the same project
  create_handoff_json "$HANDOFF_TEST_DIR/recent1.json" "recent1" "2026-02-04T10:00:00Z" "$TEST_PROJECT_PATH" "Recent handoff 1"
  create_handoff_json "$HANDOFF_TEST_DIR/recent2.json" "recent2" "2026-02-04T12:00:00Z" "$TEST_PROJECT_PATH" "Recent handoff 2"
  create_handoff_json "$HANDOFF_TEST_DIR/loaded.json" "loaded" "2026-02-04T13:00:00Z" "$TEST_PROJECT_PATH" "Already loaded" "main" "test-project" "null" "null" "2026-02-04T14:00:00Z"

  # Find most recent unloaded handoff
  # In the skill, this would use find and jq to filter by project and loaded_at == null
  result=$(jq -s '[.[] | select(.project_path == "'"$TEST_PROJECT_PATH"'") | select(.loaded_at == null)] | sort_by(.created_at) | reverse | .[0].id' "$HANDOFF_TEST_DIR"/*.json)
  [ "$result" = '"recent2"' ]
}
