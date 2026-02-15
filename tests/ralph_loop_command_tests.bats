#!/usr/bin/env bats
# Tests for ralph-loop plugin commands

load helpers/bats_helper

setup() {
  # Get command file paths
  CANCEL_RALPH_CMD="${PROJECT_ROOT}/commands/cancel-ralph.md"
  RALPH_INIT_CMD="${PROJECT_ROOT}/commands/ralph-init.md"
  RALPH_LOOP_CMD="${PROJECT_ROOT}/commands/ralph-loop.md"

  # Verify command files exist
  if [[ ! -f "$CANCEL_RALPH_CMD" ]]; then
    skip "cancel-ralph.md not found"
  fi
}

# cancel-ralph command tests
@test "cancel-ralph.md: exists" {
  [ -f "$CANCEL_RALPH_CMD" ]
}

@test "cancel-ralph.md: has valid frontmatter delimiter" {
  has_frontmatter_delimiter "$CANCEL_RALPH_CMD"
}

@test "cancel-ralph.md: has description field" {
  has_frontmatter_field "$CANCEL_RALPH_CMD" "description"
}

@test "cancel-ralph.md: description mentions canceling Ralph loop" {
  grep "^description:" "$CANCEL_RALPH_CMD" | grep -q "Cancel"
  grep "^description:" "$CANCEL_RALPH_CMD" | grep -q "Ralph"
}

@test "cancel-ralph.md: has allowed-tools field" {
  has_frontmatter_field "$CANCEL_RALPH_CMD" "allowed-tools"
}

@test "cancel-ralph.md: allowed-tools includes kill command" {
  grep "^allowed-tools:" "$CANCEL_RALPH_CMD" | grep -q "kill"
}

@test "cancel-ralph.md: allowed-tools includes reading PID file" {
  grep "^allowed-tools:" "$CANCEL_RALPH_CMD" | grep -q "cat .ralph/ralph.pid"
}

@test "cancel-ralph.md: allowed-tools includes removing PID file" {
  grep "^allowed-tools:" "$CANCEL_RALPH_CMD" | grep -q "rm .ralph/ralph.pid"
}

@test "cancel-ralph.md: instructions mention .ralph/ralph.pid" {
  grep -q ".ralph/ralph.pid" "$CANCEL_RALPH_CMD"
}

@test "cancel-ralph.md: instructions mention checking if PID file exists" {
  grep -q "exists" "$CANCEL_RALPH_CMD"
}

@test "cancel-ralph.md: instructions mention killing the process" {
  grep -q "kill" "$CANCEL_RALPH_CMD"
}

@test "cancel-ralph.md: instructions mention removing PID file" {
  grep -q "Remove" "$CANCEL_RALPH_CMD" && grep -q "PID" "$CANCEL_RALPH_CMD"
}

@test "cancel-ralph.md: instructions mention reporting cancellation" {
  grep -q "Report" "$CANCEL_RALPH_CMD" && grep -q "cancellation" "$CANCEL_RALPH_CMD"
}

@test "cancel-ralph.md: does NOT mention .claude/ralph-loop.local.md" {
  ! grep -q ".claude/ralph-loop.local.md" "$CANCEL_RALPH_CMD"
}

@test "cancel-ralph.md: does NOT mention iteration field" {
  ! grep -q "iteration:" "$CANCEL_RALPH_CMD"
}

# ralph-init command tests
@test "ralph-init.md: exists" {
  [ -f "$RALPH_INIT_CMD" ]
}

@test "ralph-init.md: has valid frontmatter delimiter" {
  has_frontmatter_delimiter "$RALPH_INIT_CMD"
}

@test "ralph-init.md: has description field" {
  has_frontmatter_field "$RALPH_INIT_CMD" "description"
}

# ralph-loop command tests
@test "ralph-loop.md: exists" {
  [ -f "$RALPH_LOOP_CMD" ]
}

@test "ralph-loop.md: has valid frontmatter delimiter" {
  has_frontmatter_delimiter "$RALPH_LOOP_CMD"
}

@test "ralph-loop.md: has description field" {
  has_frontmatter_field "$RALPH_LOOP_CMD" "description"
}

@test "ralph-loop.md: has allowed-tools field" {
  has_frontmatter_field "$RALPH_LOOP_CMD" "allowed-tools"
}

@test "ralph-loop.md: mentions cancel-ralph in documentation" {
  grep -q "cancel-ralph" "$RALPH_LOOP_CMD"
}

# help.md command tests
HELP_CMD="${PROJECT_ROOT}/commands/ralph-help.md"

@test "help.md: exists" {
  [ -f "$HELP_CMD" ]
}

@test "help.md: has valid frontmatter delimiter" {
  has_frontmatter_delimiter "$HELP_CMD"
}

@test "help.md: has description field" {
  has_frontmatter_field "$HELP_CMD" "description"
}

@test "help.md: mentions /ralph-init command" {
  grep -q "/ralph-init" "$HELP_CMD"
}

@test "help.md: mentions /ralph-loop command" {
  grep -q "/ralph-loop" "$HELP_CMD"
}

@test "help.md: mentions /cancel-ralph command" {
  grep -q "/cancel-ralph" "$HELP_CMD"
}

@test "help.md: explains PRD creation workflow" {
  grep -q "PRD" "$HELP_CMD" || grep -q "Product Requirements Document" "$HELP_CMD"
}

@test "help.md: explains fresh instance approach" {
  grep -q "fresh" "$HELP_CMD"
}

@test "help.md: explains bash loop mechanism" {
  grep -q "bash loop" "$HELP_CMD" || grep -q "while" "$HELP_CMD"
}

@test "help.md: mentions PRD file location" {
  grep -q "\.ralph/prd\.json" "$HELP_CMD"
}

@test "help.md: mentions progress tracking" {
  grep -q "progress" "$HELP_CMD"
}

@test "help.md: does NOT mention Stop hook" {
  ! grep -q "Stop hook" "$HELP_CMD"
}

@test "help.md: does NOT mention completion-promise" {
  ! grep -q "completion-promise" "$HELP_CMD"
}

@test "help.md: does NOT mention <promise> tags" {
  ! grep -q "<promise>" "$HELP_CMD"
}

@test "help.md: does NOT mention session-based looping" {
  ! grep -q "session" "$HELP_CMD" || ! grep -q "current session" "$HELP_CMD"
}

@test "help.md: credits snarktank/ralph inspiration" {
  grep -q "snarktank" "$HELP_CMD" || grep -q "ghuntley" "$HELP_CMD"
}
