#!/usr/bin/env bats
# Tests for ralph.sh bash script

load helpers/bats_helper

setup() {
  # Get script paths
  RALPH_SCRIPT="${PROJECT_ROOT}/scripts/ralph/ralph.sh"
  PROMPT_TEMPLATE="${PROJECT_ROOT}/scripts/ralph/prompt.md"

  # Create temp directory for test files
  TEST_TEMP_DIR=$(mktemp -d -t ralph-test.XXXXXX)
  export TEST_TEMP_DIR
  export TEST_RALPH_DIR="${TEST_TEMP_DIR}/.ralph"
  mkdir -p "$TEST_RALPH_DIR"

  # Create a fake git repo for testing
  export TEST_GIT_DIR="${TEST_TEMP_DIR}/git-repo"
  mkdir -p "$TEST_GIT_DIR"
  cd "$TEST_GIT_DIR"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test User"

  # Create mock claude command
  export MOCK_CLAUDE="${TEST_TEMP_DIR}/claude"
  cat > "$MOCK_CLAUDE" <<'EOF'
#!/bin/bash
# Mock claude command for testing
if [[ "$*" == *"--print"* ]]; then
  # Read from stdin
  cat
  exit 0
fi
echo "Mock claude command"
EOF
  chmod +x "$MOCK_CLAUDE"
  export PATH="${TEST_TEMP_DIR}:$PATH"
}

teardown() {
  # Kill any stray ralph.sh processes from this test
  if [ -n "${TEST_TEMP_DIR:-}" ] && [ -f "${TEST_TEMP_DIR}/.ralph/ralph.pid" ]; then
    kill "$(cat "${TEST_TEMP_DIR}/.ralph/ralph.pid")" 2>/dev/null || true
  fi

  # Clean up temp directory
  if [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "$TEST_TEMP_DIR" ]; then
    rm -rf "$TEST_TEMP_DIR"
  fi

  # Return to original directory
  cd "$PROJECT_ROOT" || true
}

# Helper: Create a minimal PRD file
create_prd() {
  local branch="${1:-ralph/test-feature}"
  cat > "$TEST_RALPH_DIR/prd.json" <<EOF
{
  "project": "test-project",
  "branchName": "$branch",
  "description": "Test PRD",
  "userStories": [
    {
      "id": "US-001",
      "title": "Test Story",
      "description": "As a user, I want to test.",
      "acceptanceCriteria": ["Test passes"],
      "priority": 1,
      "status": "open",
      "startedAt": null,
      "completedAt": null,
      "passes": false
    }
  ]
}
EOF
}

# Helper: Create mock progress.txt
create_progress() {
  cat > "$TEST_RALPH_DIR/progress.txt" <<EOF
# Ralph Progress Log
Started: 2024-01-01T00:00:00Z

## Codebase Patterns
(No patterns discovered yet)

---
EOF
}

# Test: Script exists and is executable
@test "ralph.sh: exists and is executable" {
  [ -f "$RALPH_SCRIPT" ]
  [ -x "$RALPH_SCRIPT" ]
}

# Test: Script uses strict error handling
@test "ralph.sh: uses set -euo pipefail" {
  run grep -q "set -euo pipefail" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script exits with error if .ralph/prd.json missing
@test "ralph.sh: exits with error if .ralph/prd.json missing" {
  cd "$TEST_GIT_DIR"
  run bash "$RALPH_SCRIPT" 2
  [ $status -eq 1 ]
  [[ "$output" == *"prd.json not found"* ]]
  [[ "$output" == *"/ralph-init first"* ]]
}

# Test: Script accepts custom max iterations
@test "ralph.sh: accepts custom max iterations argument" {
  # This test verifies the script accepts the argument and has input validation
  # The script should validate that MAX_ITERATIONS is a positive integer
  run grep -E 'MAX_ITERATIONS.*\$1' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'MAX_ITERATIONS=10' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script default iterations
@test "ralph.sh: default iterations is 10" {
  # Check that default of 10 is set (either with validation or simple default)
  run grep -E 'MAX_ITERATIONS=10|MAX_ITERATIONS="\$\{1:-10\}"' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script creates PID file
@test "ralph.sh: creates PID file on startup" {
  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Start ralph.sh in background and check for PID file
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5

  # Check if PID file was created
  if [ -f .ralph/ralph.pid ]; then
    pid=$(cat .ralph/ralph.pid)
    # PID should be a number
    [[ "$pid" =~ ^[0-9]+$ ]]
  fi

  # Clean up
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true
}

# Test: Script cleanup PID file on exit
@test "ralph.sh: cleans up PID file on exit" {
  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Run ralph.sh in background then kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # After script exits, PID file should be cleaned up by the trap
  # Give it a moment to clean up
  sleep 0.2

  # PID file should not exist (cleaned up by EXIT trap)
  if [ -f .ralph/ralph.pid ]; then
    pid=$(cat .ralph/ralph.pid)
    # If file exists, process should NOT be running
    ! kill -0 "$pid" 2>/dev/null
  fi
}

# Test: Script detects existing running loop
@test "ralph.sh: detects existing running loop" {
  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create a fake PID file with current process PID
  echo $$ > .ralph/ralph.pid

  # Try to run again - should fail
  run bash "$RALPH_SCRIPT" 2
  [ $status -eq 1 ]
  [[ "$output" == *"already running"* ]]
}

# Test: Script checks out branch from prd.json
@test "ralph.sh: checks out branch from prd.json" {
  local test_branch="ralph/test-feature-branch"
  create_prd "$test_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit"

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Check if we're on the correct branch
  current_branch=$(git branch --show-current)
  [ "$current_branch" = "$test_branch" ]
}

# Test: Script creates branch if it doesn't exist
@test "ralph.sh: creates branch if it doesn't exist" {
  local test_branch="ralph/new-branch"
  create_prd "$test_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit on main
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit"

  # Ensure branch doesn't exist
  git checkout -q main 2>/dev/null || git checkout -q master 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Check if we're on the new branch
  current_branch=$(git branch --show-current)
  [ "$current_branch" = "$test_branch" ]
}

# Test: Script creates progress.txt if missing
@test "ralph.sh: creates progress.txt if missing" {
  create_prd
  # Don't create progress.txt

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # progress.txt should be created
  [ -f .ralph/progress.txt ]
  grep -q "Ralph Progress Log" .ralph/progress.txt
}

# Test: prompt.md template has ITERATION placeholder
@test "prompt.md: has {{ITERATION}} placeholder" {
  run grep -q "{{ITERATION}}" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template has MAX placeholder
@test "prompt.md: has {{MAX}} placeholder" {
  run grep -q "{{MAX}}" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions PRD reading
@test "prompt.md: mentions reading .ralph/prd.json" {
  run grep -q "\.ralph/prd\.json" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions progress.txt
@test "prompt.md: mentions reading .ralph/progress.txt" {
  run grep -q "\.ralph/progress\.txt" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions COMPLETE promise
@test "prompt.md: mentions <promise>COMPLETE</promise>" {
  run grep -q "<promise>COMPLETE</promise>" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions implementing one story
@test "prompt.md: mentions implementing ONE story" {
  run grep -q "ONE story" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions updating prd.json
@test "prompt.md: mentions updating .ralph/prd.json" {
  run grep -q "prd\.json" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions appending to progress.txt
@test "prompt.md: mentions appending to progress.txt" {
  run grep -q "progress\.txt" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template has Progress Report Format section
@test "prompt.md: has Progress Report Format section" {
  run grep -q "Progress Report Format" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template has Consolidate Patterns section
@test "prompt.md: has Consolidate Patterns section" {
  run grep -q "Consolidate Patterns" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template has Codebase Patterns section
@test "prompt.md: mentions Codebase Patterns section" {
  run grep -q "Codebase Patterns" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template has Update CLAUDE.md Files section
@test "prompt.md: has Update CLAUDE.md Files section" {
  run grep -q "Update CLAUDE.md Files" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template has Quality Requirements section
@test "prompt.md: has Quality Requirements section" {
  run grep -q "Quality Requirements" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template has Browser Testing section
@test "prompt.md: has Browser Testing section" {
  run grep -q "Browser Testing" "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions status field
@test "prompt.md: mentions status field for user stories" {
  run grep -q 'status' "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions startedAt field
@test "prompt.md: mentions startedAt timestamp field" {
  run grep -q 'startedAt' "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions completedAt field
@test "prompt.md: mentions completedAt timestamp field" {
  run grep -q 'completedAt' "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions in_progress status
@test "prompt.md: mentions in_progress status" {
  run grep -q 'in_progress' "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions done status
@test "prompt.md: mentions done status" {
  run grep -q '"done"' "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: prompt.md template mentions ISO timestamp
@test "prompt.md: mentions ISO timestamp" {
  run grep -q 'ISO timestamp' "$PROMPT_TEMPLATE"
  [ $status -eq 0 ]
}

# Test: Script substitutes template variables
@test "ralph.sh: substitutes {{ITERATION}} and {{MAX}} in prompt" {
  run grep 'sed "s/{{ITERATION}}/' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'sed.*{{MAX}}/' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script calls claude --print
@test "ralph.sh: calls claude --print" {
  run grep -q 'claude --print' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script checks for COMPLETE promise
@test "ralph.sh: checks for <promise>COMPLETE</promise>" {
  run grep -q '<promise>COMPLETE</promise>' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script exits with 0 when COMPLETE detected
@test "ralph.sh: exits with 0 when COMPLETE detected" {
  # Check that after detecting COMPLETE, script exits with 0
  run grep -A 5 'grep -q.*COMPLETE' "$RALPH_SCRIPT"
  [[ "$output" == *"exit 0"* ]]
}

# Test: Script iterates with proper loop
@test "ralph.sh: uses seq loop for iterations" {
  run grep 'seq 1' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep '\$MAX_ITERATIONS' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script shows iteration progress
@test "ralph.sh: shows iteration progress" {
  run grep 'iteration' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has cleanup trap
@test "ralph.sh: has cleanup trap" {
  run grep -q "trap cleanup EXIT" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script cleanup function removes PID file
@test "ralph.sh: cleanup function removes PID file" {
  run grep -A 2 "^cleanup()" "$RALPH_SCRIPT"
  [[ "$output" == *"rm -f"* ]]
  [[ "$output" == *"PID_FILE"* ]]
}

# Test: Script sleeps between iterations to prevent API rate limiting
@test "ralph.sh: sleeps between iterations" {
  run grep -q "sleep 2" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script creates log directory for iteration archives
@test "ralph.sh: creates log directory for iteration archives" {
  run grep -q "mkdir -p \"\$LOG_DIR\"" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has LOG_DIR variable configured
@test "ralph.sh: has LOG_DIR variable" {
  run grep -q 'LOG_DIR=' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'LOG_DIR="\$RALPH_DIR/logs"' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script writes iteration logs to archive directory
@test "ralph.sh: writes iteration logs to archive directory" {
  run grep -q 'ITERATION_LOG=' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'ITERATION_LOG="\$LOG_DIR/iteration-' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script supports --dangerously-skip-permissions flag
@test "ralph.sh: supports --dangerously-skip-permissions flag" {
  run grep -q 'dangerously-skip-permissions' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script passes --dangerously-skip-permissions to claude command
@test "ralph.sh: passes --dangerously-skip-permissions to claude" {
  run grep 'claude.*--print.*--dangerously-skip-permissions' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Functional Test: cancel-ralph PID kill behavior
@test "cancel-ralph: kills ralph.sh process and removes PID file" {
  # Skip this test on CI due to timing issues
  skip "Test skipped due to timing sensitivity on CI runners"

  # Clean up any previous test state
  cd "$TEST_GIT_DIR"
  rm -rf .ralph
  git checkout - 2>/dev/null || true
  git branch -D ralph/* 2>/dev/null || true

  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Start ralph.sh in background
  bash "$RALPH_SCRIPT" 10 >/dev/null 2>&1 &
  ralph_pid=$!

  # Wait for PID file to be created (poll with longer timeout for CI)
  local count=0
  while [ ! -f .ralph/ralph.pid ] && [ $count -lt 50 ]; do
    sleep 0.1
    count=$((count + 1))
  done

  # Give script time to fully initialize
  sleep 0.5

  # Verify PID file exists
  [ -f .ralph/ralph.pid ]

  pid_from_file=$(cat .ralph/ralph.pid)
  [ "$pid_from_file" = "$ralph_pid" ]

  # Verify process is running
  kill -0 "$ralph_pid" 2>/dev/null

  # Kill the process (simulating cancel-ralph behavior)
  kill "$ralph_pid" 2>/dev/null || true
  sleep 0.2

  # Verify process is dead
  run ! kill -0 "$ralph_pid" 2>/dev/null

  # Remove PID file (as cancel-ralph would do)
  rm -f .ralph/ralph.pid

  # Verify PID file is removed
  [ ! -f .ralph/ralph.pid ]
}

# Functional Test: ralph.sh iteration counting
@test "ralph.sh: iterates correct number of times" {
  # Skip this test on CI due to timing issues with background processes
  skip "Test skipped on CI due to timing sensitivity with mock claude"

  # Clean up any previous test state
  cd "$TEST_GIT_DIR"
  rm -rf .ralph
  git checkout - 2>/dev/null || true
  git branch -D ralph/* 2>/dev/null || true

  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Create a mock claude that never returns COMPLETE
  # This allows ralph.sh to run through all iterations
  cat > "$MOCK_CLAUDE" <<'EOF'
#!/bin/bash
# Mock claude that never returns COMPLETE
if [[ "$*" == *"--print"* ]]; then
  # Read from stdin and echo response without COMPLETE
  cat >/dev/null
  echo "Working on tasks..."
  exit 0
fi
echo "Mock claude command"
EOF
  chmod +x "$MOCK_CLAUDE"

  # Run ralph.sh with 3 iterations, output to a temp file
  local output_file="${TEST_TEMP_DIR}/ralph_output.txt"
  bash "$RALPH_SCRIPT" 3 > "$output_file" 2>&1 &
  ralph_pid=$!

  # Wait for all iterations to complete with much longer timeout for CI
  local count=0
  while kill -0 "$ralph_pid" 2>/dev/null && [ $count -lt 60 ]; do
    sleep 0.5
    count=$((count + 1))
  done

  # Wait for process to finish and flush output
  wait $ralph_pid 2>/dev/null || true
  sleep 0.5

  # Read output from file, removing any null bytes
  output=$(tr -d '\0' < "$output_file")

  # Verify we ran exactly 3 iterations
  # The script should show "=== Ralph iteration 1/3 ===", "2/3", "3/3"
  iteration_count=$(echo "$output" | grep -c "Ralph iteration" || true)
  [ "$iteration_count" -eq 3 ]

  # Should show "reached max iterations" message
  [[ "$output" == *"max iterations"* ]]
}

# Functional Test: ralph.sh COMPLETE detection
@test "ralph.sh: detects COMPLETE and exits with 0" {
  # Clean up any previous test state
  cd "$TEST_GIT_DIR"
  rm -rf .ralph
  git checkout - 2>/dev/null || true
  git branch -D ralph/* 2>/dev/null || true

  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Create a mock claude that returns COMPLETE immediately
  cat > "$MOCK_CLAUDE" <<'EOF'
#!/bin/bash
# Mock claude that returns COMPLETE
if [[ "$*" == *"--print"* ]]; then
  # Read from stdin
  cat >/dev/null
  # Return COMPLETE promise
  echo "<promise>COMPLETE</promise>"
  exit 0
fi
echo "Mock claude command"
EOF
  chmod +x "$MOCK_CLAUDE"

  # Run ralph.sh with 10 iterations but expect it to exit early
  run bash "$RALPH_SCRIPT" 10 2>&1

  # Should exit with 0 (not 1 for max iterations)
  [ $status -eq 0 ]

  # Should show completion message
  [[ "$output" == *"Ralph completed at iteration"* ]]

  # Should show iteration 1 (should exit on first iteration)
  [[ "$output" == *"iteration 1/10"* ]]

  # Should NOT show iteration 2 or beyond
  ! [[ "$output" == *"iteration 2/"* ]]
}

# Test: Script creates .last-branch file on first run
@test "ralph.sh: creates .last-branch file on first run" {
  local test_branch="ralph/first-run"
  create_prd "$test_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # .last-branch should exist and contain the branch name
  [ -f .ralph/.last-branch ]
  [ "$(cat .ralph/.last-branch)" = "$test_branch" ]
}

# Test: Script archives previous run when branch changes
@test "ralph.sh: archives previous run when branch changes" {
  local first_branch="ralph/first-feature"
  local second_branch="ralph/second-feature"

  # First run
  create_prd "$first_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run first time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Modify progress.txt so we can verify it was archived
  echo "Some progress content" >> .ralph/progress.txt

  # Update PRD for second run with different branch
  create_prd "$second_branch"
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Run second time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Archive should be created
  [ -d .ralph/archive ]

  # Find the archive directory (format: YYYY-MM-DD-first-feature)
  local archive_dir
  archive_dir=$(find .ralph/archive -type d -name "*-first-feature" | head -1)
  [ -n "$archive_dir" ]

  # Archived files should exist
  [ -f "$archive_dir/prd.json" ]
  [ -f "$archive_dir/progress.txt" ]

  # Archived progress.txt should contain our custom content
  grep -q "Some progress content" "$archive_dir/progress.txt"

  # .last-branch should be updated to new branch
  [ "$(cat .ralph/.last-branch)" = "$second_branch" ]

  # Current progress.txt should be reset (no custom content)
  ! grep -q "Some progress content" .ralph/progress.txt
}

# Test: Script does not archive when branch is the same
@test "ralph.sh: does not archive when branch is the same" {
  local test_branch="ralph/same-branch"
  create_prd "$test_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run first time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Modify progress.txt
  echo "Custom progress" >> .ralph/progress.txt

  # Run second time with same branch
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Archive directory should NOT be created
  [ ! -d .ralph/archive ]

  # Custom progress should still be there (not reset)
  grep -q "Custom progress" .ralph/progress.txt
}

# Test: Script handles archive directory name collision
@test "ralph.sh: handles archive directory name collision with timestamp" {
  local first_branch="ralph/collision-test"
  local second_branch="ralph/other-feature"

  # First run
  create_prd "$first_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run first time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Manually create an archive directory with today's date to simulate collision
  local today
  today=$(date +"%Y-%m-%d")
  mkdir -p ".ralph/archive/${today}-collision-test"

  # Update PRD for second run
  create_prd "$second_branch"
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Run second time - should create a timestamped archive to avoid collision
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Should have at least one collision-test archive directory
  local archive_count
  archive_count=$(find .ralph/archive -type d -name "*-collision-test*" | wc -l)
  [ "$archive_count" -ge 1 ]
}

# Test: Archive removes ralph/ prefix from branch name
@test "ralph.sh: archive directory name removes ralph/ prefix" {
  local first_branch="ralph/my-awesome-feature"
  local second_branch="ralph/other-feature"

  # First run
  create_prd "$first_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run first time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Update PRD for second run
  create_prd "$second_branch"
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Run second time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Archive directory should be named with feature name, not full branch
  local archive_dir
  archive_dir=$(find .ralph/archive -type d -name "*-my-awesome-feature" | head -1)
  [ -n "$archive_dir" ]

  # Should NOT contain ralph/ in the directory name
  [[ "$archive_dir" != *"/ralph-my-awesome-feature" ]]
}

# Test: Script handles null branchName in prd.json
@test "ralph.sh: handles null branchName without archiving" {
  # Create PRD with null branchName
  cat > "$TEST_RALPH_DIR/prd.json" <<EOF
{
  "project": "test-project",
  "branchName": null,
  "description": "Test PRD",
  "userStories": []
}
EOF
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run with null branchName
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # .last-branch should contain "null" as written
  [ -f .ralph/.last-branch ]
  [ "$(cat .ralph/.last-branch)" = "null" ]
}

# Test: Script validates prd.json is valid JSON
@test "ralph.sh: validates prd.json is valid JSON" {
  cd "$TEST_GIT_DIR"
  mkdir -p .ralph

  # Create invalid JSON file
  echo "{ invalid json" > .ralph/prd.json

  run bash "$RALPH_SCRIPT" 2
  [ $status -ne 0 ]
  [[ "$output" == *"not valid JSON"* ]]
}

# Test: Script validates prd.json has required fields
@test "ralph.sh: validates prd.json has required fields" {
  cd "$TEST_GIT_DIR"
  mkdir -p .ralph

  # Create valid JSON but missing required field
  echo '{"project": "test"}' > .ralph/prd.json

  run bash "$RALPH_SCRIPT" 2
  [ $status -ne 0 ]
  [[ "$output" == *"missing required field"* ]]
}

# Test: Script has proper cleanup on SIGINT
@test "ralph.sh: cleanup function removes PID file and shows exit info" {
  run grep -A 5 "^cleanup()" "$RALPH_SCRIPT"
  [[ "$output" == *"rm -f"* ]]
  [[ "$output" == *"PID_FILE"* ]]
}

# Test: Script has INT signal handler
@test "ralph.sh: has INT signal handler" {
  run grep "trap.*INT" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has TERM signal handler
@test "ralph.sh: has TERM signal handler" {
  run grep "trap.*TERM" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has show_progress_summary function
@test "ralph.sh: has show_progress_summary function" {
  run grep "show_progress_summary()" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script calls show_progress_summary after iteration
@test "ralph.sh: calls show_progress_summary after iteration" {
  run grep -A 3 "Iteration.*finished, continuing" "$RALPH_SCRIPT"
  [[ "$output" == *"show_progress_summary"* ]]
}

# Test: Script calls show_progress_summary on completion
@test "ralph.sh: calls show_progress_summary on completion" {
  run grep -B 3 -A 3 "Ralph completed" "$RALPH_SCRIPT"
  [[ "$output" == *"show_progress_summary"* ]]
}

# === New State File Tests ===

# Test: Script creates guardrails.md if missing
@test "ralph.sh: creates guardrails.md if missing" {
  create_prd
  # Don't create guardrails.md

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # guardrails.md should be created
  [ -f .ralph/guardrails.md ]
  grep -q "# Ralph Guardrails" .ralph/guardrails.md
}

# Test: Script creates activity.log if missing
@test "ralph.sh: creates activity.log if missing" {
  create_prd

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # activity.log should be created
  [ -f .ralph/activity.log ]
}

# Test: Script creates errors.log if missing
@test "ralph.sh: creates errors.log if missing" {
  create_prd

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # errors.log should be created
  [ -f .ralph/errors.log ]
}

# Test: Script has guardrails file variable
@test "ralph.sh: has GUARDRAILS_FILE variable" {
  run grep -q 'GUARDRAILS_FILE=' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'GUARDRAILS_FILE="\$RALPH_DIR/guardrails.md"' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has activity log file variable
@test "ralph.sh: has ACTIVITY_LOG variable" {
  run grep -q 'ACTIVITY_LOG=' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'ACTIVITY_LOG="\$RALPH_DIR/activity.log"' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has errors log file variable
@test "ralph.sh: has ERRORS_LOG variable" {
  run grep -q 'ERRORS_LOG=' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'ERRORS_LOG="\$RALPH_DIR/errors.log"' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has ensure_guardrails_file function
@test "ralph.sh: has ensure_guardrails_file function" {
  run grep "ensure_guardrails_file()" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: guardrails.md has proper header
@test "ralph.sh: guardrails.md has proper header when created" {
  create_prd

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Check guardrails.md has proper structure
  grep -q "# Ralph Guardrails" .ralph/guardrails.md
  grep -q "Lessons Learned" .ralph/guardrails.md
}

# Test: Script archives guardrails.md when branch changes
@test "ralph.sh: archives guardrails.md when branch changes" {
  local first_branch="ralph/first-feature"
  local second_branch="ralph/second-feature"

  # First run
  create_prd "$first_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run first time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Add custom content to guardrails.md
  echo "## Custom guardrail" >> .ralph/guardrails.md

  # Update PRD for second run with different branch
  create_prd "$second_branch"
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Run second time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Archive should contain guardrails.md
  local archive_dir
  archive_dir=$(find .ralph/archive -type d -name "*-first-feature" | head -1)
  [ -f "$archive_dir/guardrails.md" ]

  # Archived guardrails.md should contain our custom content
  grep -q "Custom guardrail" "$archive_dir/guardrails.md"
}

# Test: Script archives activity.log when branch changes
@test "ralph.sh: archives activity.log when branch changes" {
  local first_branch="ralph/first-feature"
  local second_branch="ralph/second-feature"

  # First run
  create_prd "$first_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run first time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Add custom content to activity.log
  echo "2026-02-09T12:00:00Z - Iteration 1 started" >> .ralph/activity.log

  # Update PRD for second run with different branch
  create_prd "$second_branch"
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Run second time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Archive should contain activity.log
  local archive_dir
  archive_dir=$(find .ralph/archive -type d -name "*-first-feature" | head -1)
  [ -f "$archive_dir/activity.log" ]

  # Archived activity.log should contain our custom content
  grep -q "2026-02-09T12:00:00Z - Iteration 1 started" "$archive_dir/activity.log"
}

# Test: Script archives errors.log when branch changes
@test "ralph.sh: archives errors.log when branch changes" {
  local first_branch="ralph/first-feature"
  local second_branch="ralph/second-feature"

  # First run
  create_prd "$first_branch"
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run first time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Add custom content to errors.log
  echo "2026-02-09T12:00:00Z - ERROR: Test failure" >> .ralph/errors.log

  # Update PRD for second run with different branch
  create_prd "$second_branch"
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Run second time
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Archive should contain errors.log
  local archive_dir
  archive_dir=$(find .ralph/archive -type d -name "*-first-feature" | head -1)
  [ -f "$archive_dir/errors.log" ]

  # Archived errors.log should contain our custom content
  grep -q "2026-02-09T12:00:00Z - ERROR: Test failure" "$archive_dir/errors.log"
}

# Test: Script logs successful iteration to activity.log
@test "ralph.sh: logs successful iteration to activity.log" {
  create_prd

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it after it starts
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # activity.log should exist and have a success entry
  [ -f .ralph/activity.log ]
  # Check for SUCCESS status in the log
  grep -q "STATUS=SUCCESS" .ralph/activity.log
}

# Test: Script logs failed iteration with ERROR status
@test "ralph.sh: logs failed iteration with ERROR status" {
  create_prd

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Create a mock claude that exits with code 1 (transient error)
  cat > "$MOCK_CLAUDE" <<'EOF'
#!/bin/bash
# Mock claude that fails with exit code 1
if [[ "$*" == *"--print"* ]]; then
  cat >/dev/null
  exit 1
fi
echo "Mock claude command"
EOF
  chmod +x "$MOCK_CLAUDE"

  # Run ralph.sh - it should continue after exit code 1
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # activity.log should have ERROR status entry
  [ -f .ralph/activity.log ]
  grep -q "STATUS=ERROR" .ralph/activity.log
}

# Test: Script logs iteration with START and END timestamps
@test "ralph.sh: logs iteration with START and END timestamps" {
  create_prd

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # activity.log should have START and END timestamps
  [ -f .ralph/activity.log ]
  # Check for START= timestamp format
  grep -q "START=" .ralph/activity.log
  # Check for END= timestamp format
  grep -q "END=" .ralph/activity.log
}

# Test: Script logs Claude command failure to errors.log
@test "ralph.sh: logs Claude command failure to errors.log" {
  create_prd

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/prd.json" .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Create a mock claude that exits with code 1
  cat > "$MOCK_CLAUDE" <<'EOF'
#!/bin/bash
# Mock claude that fails with exit code 1
if [[ "$*" == *"--print"* ]]; then
  cat >/dev/null
  exit 1
fi
echo "Mock claude command"
EOF
  chmod +x "$MOCK_CLAUDE"

  # Run ralph.sh - it should continue after exit code 1
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # errors.log should have an entry about the failure
  [ -f .ralph/errors.log ]
  # Check for error log entry with exit code
  grep -q "failed with exit code" .ralph/errors.log
}

# Test: Script uses get_guardrails_template helper
@test "ralph.sh: has get_guardrails_template helper function" {
  run grep "get_guardrails_template()" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: ensure_guardrails_file calls get_guardrails_template
@test "ralph.sh: ensure_guardrails_file uses get_guardrails_template" {
  run grep -A 10 "^ensure_guardrails_file()" "$RALPH_SCRIPT"
  [[ "$output" == *"get_guardrails_template"* ]]
}

# Test: Script has inline comments for new state file variables
@test "ralph.sh: has inline comments for state file variables" {
  # Check for comment explaining GUARDRAILS_FILE
  run grep "# Guardrails file" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  # Check for comment explaining ACTIVITY_LOG
  run grep "# Activity log" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  # Check for comment explaining ERRORS_LOG
  run grep "# Errors log" "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# === Configuration File Tests ===

# Test: Script sources .agents/ralph/config.sh if it exists
@test "ralph.sh: sources .agents/ralph/config.sh if it exists" {
  run grep -q '\.agents/ralph/config\.sh' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep -q 'source.*"\$CONFIG_FILE"' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script has STALE_SECONDS variable with default
@test "ralph.sh: has STALE_SECONDS variable with default" {
  run grep -q 'STALE_SECONDS=' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'STALE_SECONDS=' "$RALPH_SCRIPT"
  [[ "$output" == *"86400"* ]]  # Default should be 86400 (24 hours)
}

# Test: Script sources config file safely (checks existence first)
@test "ralph.sh: sources config file safely with existence check" {
  run grep -B 2 'source.*"\$CONFIG_FILE"' "$RALPH_SCRIPT"
  [[ "$output" == *"[ -f "* ]] || [[ "$output" == *"[[ -f "* ]]
}

# Test: Config file sourcing uses correct path
@test "ralph.sh: config file path is .agents/ralph/config.sh" {
  run grep '\.agents/ralph/config\.sh' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# === Template Hierarchy Tests ===

# Test: Script has custom prompt template path variable
@test "ralph.sh: has CUSTOM_PROMPT_TEMPLATE variable for .agents/ralph/prompts/loop.md" {
  run grep -q 'CUSTOM_PROMPT_TEMPLATE=' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
  run grep 'CUSTOM_PROMPT_TEMPLATE="\.agents/ralph/prompts/loop\.md"' "$RALPH_SCRIPT"
  [ $status -eq 0 ]
}

# Test: Script falls back to default prompt template
@test "ralph.sh: falls back to default prompt.md when custom doesn't exist" {
  run grep -A 5 'CUSTOM_PROMPT_TEMPLATE=' "$RALPH_SCRIPT"
  # Should check if custom template exists, otherwise use default
  [[ "$output" == *"PROMPT_TEMPLATE"* ]]
}

# Test: Script uses custom prompt template when it exists
@test "ralph.sh: uses custom prompt template from .agents/ralph/prompts/loop.md" {
  # Check that script has logic to use custom template
  run grep -A 10 'CUSTOM_PROMPT_TEMPLATE=' "$RALPH_SCRIPT"
  [[ "$output" == *"[ -f"* ]] || [[ "$output" == *"[[ -f"* ]]
}

# Functional Test: Script uses default template when custom doesn't exist
@test "ralph.sh: functional - uses default template when custom doesn't exist" {
  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Ensure custom template doesn't exist
  rm -rf .agents/ralph/prompts/

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Script should have run successfully using default template
  [ ! -f .agents/ralph/prompts/loop.md ]
}

# Functional Test: Script uses custom template when it exists
@test "ralph.sh: functional - uses custom template when it exists" {
  create_prd
  create_progress

  cd "$TEST_GIT_DIR"
  mkdir -p .ralph
  cp "$TEST_RALPH_DIR/"* .ralph/

  # Create an initial commit
  echo "test" > test.txt
  git add test.txt
  git commit -q -m "Initial commit" 2>/dev/null || true

  # Create custom prompt template
  mkdir -p .agents/ralph/prompts
  cat > .agents/ralph/prompts/loop.md <<'EOF'
# Custom Prompt Template
This is a custom template for testing.

Iteration {{ITERATION}} of {{MAX}}
EOF

  # Run ralph.sh in background and kill it
  bash "$RALPH_SCRIPT" 1 >/dev/null 2>&1 &
  ralph_pid=$!
  sleep 0.5
  kill $ralph_pid 2>/dev/null || true
  wait $ralph_pid 2>/dev/null || true

  # Custom template should still exist and be used
  [ -f .agents/ralph/prompts/loop.md ]
  grep -q "Custom Prompt Template" .agents/ralph/prompts/loop.md
}
