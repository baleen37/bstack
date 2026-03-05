#!/usr/bin/env bats
# Test suite for dispatch SKILL.md correctness

load '../helpers/bats_helper'

setup() {
  export SKILL_MD="${BATS_TEST_DIRNAME}/../../plugins/me/skills/dispatch/SKILL.md"

  if [[ ! -f "$SKILL_MD" ]]; then
    skip "SKILL.md not found"
  fi

  export CONTENT
  CONTENT=$(cat "$SKILL_MD")
}

# --- Semicolon rule ---

@test "uses semicolon (;) not && before tmux wait-for -S in codex example" {
  # && causes permanent hang if AI fails; ; always signals
  grep -q '; tmux wait-for -S' "$SKILL_MD"
}

@test "does not use && before tmux wait-for -S" {
  run grep '&& tmux wait-for -S' "$SKILL_MD"
  [ "$status" -ne 0 ]
}

@test "rules section says to use ; not && before signal" {
  grep -q 'Use `;`' "$SKILL_MD" || grep -q "Use \`;'" "$SKILL_MD" || \
    grep -q '; tmux wait-for' "$SKILL_MD"
}

# --- send-keys -l flag ---

@test "send-keys uses -l flag for literal input" {
  grep -q 'send-keys.*-l' "$SKILL_MD"
}

# --- Failure detection ---

@test "documents result file check for failure detection" {
  grep -q '\-s.*RESULT\|RESULT.*\-s' "$SKILL_MD"
}

# --- timeout ---

@test "does not recommend timeout command without macOS caveat" {
  # timeout is not available on macOS by default
  if grep -q 'timeout 300' "$SKILL_MD"; then
    grep -q 'macOS\|gtimeout\|coreutils' "$SKILL_MD"
  fi
}

# --- TASK_FILE cleanup ---

@test "cleanup includes TASK_FILE removal when task file is used" {
  grep -q 'TASK_FILE' "$SKILL_MD" && \
    grep -q 'rm.*TASK_FILE\|TASK_FILE.*rm' "$SKILL_MD" || \
    ! grep -q 'TASK_FILE' "$SKILL_MD"
}

# --- OpenCode ---

@test "description does not mention OpenCode if no OpenCode section exists" {
  if grep -q 'OpenCode' "$SKILL_MD"; then
    # If mentioned in description, must have a section or note
    grep -q '^## OpenCode\|OpenCode.*not.*supported\|OpenCode.*coming' "$SKILL_MD"
  fi
}
