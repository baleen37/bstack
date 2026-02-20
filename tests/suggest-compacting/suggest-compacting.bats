#!/usr/bin/env bats
# suggest-compacting tests for consolidated structure
# After consolidation, suggest-compacting is integrated into the root plugin
# dist files are at PROJECT_ROOT/dist/

load ../helpers/bats_helper

DIST_DIR="${PROJECT_ROOT}/dist"

setup() {
  export TEST_SESSION_ID="test-session-123"
  export TEST_STATE_DIR="$HOME/.claude/suggest-compacting"
  export TEST_STATE_FILE="$TEST_STATE_DIR/tool-count-$TEST_SESSION_ID.txt"
  export CLAUDE_PLUGIN_ROOT="${PROJECT_ROOT}"

  # Clean up any existing test state
  rm -f "$TEST_STATE_FILE" 2>/dev/null || true
}

teardown() {
  rm -f "$TEST_STATE_FILE" 2>/dev/null || true
}

@test "suggest-compacting: dist/auto-compact.js exists" {
  [ -f "$DIST_DIR/auto-compact.js" ]
}

@test "suggest-compacting: dist/session-start.js exists" {
  [ -f "$DIST_DIR/session-start.js" ]
}

@test "suggest-compacting: hooks.json references auto-compact.js" {
  local hooks_json="${PROJECT_ROOT}/hooks/hooks.json"
  [ -f "$hooks_json" ]
  grep -q "auto-compact.js" "$hooks_json"
}

@test "suggest-compacting: hooks.json references session-start.js" {
  local hooks_json="${PROJECT_ROOT}/hooks/hooks.json"
  [ -f "$hooks_json" ]
  grep -q "session-start.js" "$hooks_json"
}

@test "suggest-compacting: auto-compact.js is not empty" {
  [ -s "$DIST_DIR/auto-compact.js" ]
}

@test "suggest-compacting: session-start.js is not empty" {
  [ -s "$DIST_DIR/session-start.js" ]
}
