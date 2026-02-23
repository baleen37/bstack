#!/usr/bin/env bats
# Test suite for create-pr skill scripts

load '../helpers/bats_helper'

setup() {
  export VERIFY_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/verify-pr-status.sh"
  export SYNC_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/sync-with-base.sh"
}

@test "verify-pr-status.sh is executable" {
  [ -x "$VERIFY_SCRIPT" ]
}

@test "verify-pr-status.sh uses strict error handling" {
  run grep -q "set -euo pipefail" "$VERIFY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "verify-pr-status.sh documents exit codes" {
  run grep -A 3 "Exit codes:" "$VERIFY_SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"0 - PR is merge-ready"* ]]
  [[ "$output" == *"1 - Action required"* ]]
  [[ "$output" == *"2 - Pending"* ]]
}

@test "verify-pr-status.sh checks required CI status" {
  run grep -q "statusCheckRollup" "$VERIFY_SCRIPT"
  [ "$status" -eq 0 ]
  run grep -q "isRequired==true" "$VERIFY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "verify-pr-status.sh handles BEHIND status without auto-merge" {
  run grep -q "BEHIND)" "$VERIFY_SCRIPT"
  [ "$status" -eq 0 ]
  run grep -q "sync-with-base.sh" "$VERIFY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "verify-pr-status.sh is read-only" {
  run grep -Eq "^[[:space:]]*git[[:space:]]+(merge|push)\\b" "$VERIFY_SCRIPT"
  [ "$status" -ne 0 ]
}

@test "sync-with-base.sh exists and is executable" {
  [ -x "$SYNC_SCRIPT" ]
}
