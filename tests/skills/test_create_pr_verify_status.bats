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
  run grep -Eq "git fetch|git merge" "$VERIFY_SCRIPT"
  [ "$status" -eq 0 ]
}

@test "verify-pr-status.sh is read-only" {
  run grep -Eq "^[[:space:]]*git[[:space:]]+(merge|push)\\b" "$VERIFY_SCRIPT"
  [ "$status" -ne 0 ]
}

@test "sync-with-base.sh exists and is executable" {
  [ -x "$SYNC_SCRIPT" ]
}

# ===== preflight-check.sh tests =====

@test "preflight-check.sh is executable" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  [ -x "$PREFLIGHT_SCRIPT" ]
}

@test "preflight-check.sh has proper shebang" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  head -n 1 "$PREFLIGHT_SCRIPT" | grep -q "^#!/usr/bin/env bash"
}

@test "preflight-check.sh uses set -euo pipefail" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  grep -q "set -euo pipefail" "$PREFLIGHT_SCRIPT"
}

@test "preflight-check.sh documents exit codes" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  grep -q "Exit codes:" "$PREFLIGHT_SCRIPT"
  grep -q "0 " "$PREFLIGHT_SCRIPT"
  grep -q "1 " "$PREFLIGHT_SCRIPT"
  grep -q "2 " "$PREFLIGHT_SCRIPT"
}

@test "preflight-check.sh: exits 2 when not in a git repository" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  run env -u GIT_DIR -u GIT_WORK_TREE "$PREFLIGHT_SCRIPT" main
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Not in a git repository" ]]
  rm -rf "$TEMP_DIR"
}

@test "preflight-check.sh: exits 2 when no base branch given and gh fails" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  run env -u GIT_DIR -u GIT_WORK_TREE "$PREFLIGHT_SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" =~ "ERROR" ]]
  rm -rf "$TEMP_DIR"
}

@test "preflight-check.sh: does not print color escape sequences" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  run grep -Eq "\\\\033|RED=|GREEN=|YELLOW=" "$PREFLIGHT_SCRIPT"
  [ "$status" -ne 0 ]
}

# ===== preflight-check.sh integration tests =====

setup_git_repos() {
  # Create bare "remote" repo and two clones
  export TEST_REMOTE=$(mktemp -d)
  export TEST_CLONE_A=$(mktemp -d)
  export TEST_CLONE_B=$(mktemp -d)

  git init --bare "$TEST_REMOTE" >/dev/null 2>&1
  git clone "$TEST_REMOTE" "$TEST_CLONE_A" >/dev/null 2>&1
  git clone "$TEST_REMOTE" "$TEST_CLONE_B" >/dev/null 2>&1

  # Create initial commit on main
  cd "$TEST_CLONE_A"
  echo "init" > file.txt
  git add file.txt
  git commit -m "initial commit" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  cd "$TEST_CLONE_B"
  git pull origin main >/dev/null 2>&1
}

teardown_git_repos() {
  rm -rf "$TEST_REMOTE" "$TEST_CLONE_A" "$TEST_CLONE_B"
}

@test "preflight-check.sh: exits 0 when branch is up to date and clean" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  setup_git_repos

  cd "$TEST_CLONE_A"
  git checkout -b feature/test >/dev/null 2>&1
  echo "change" >> file.txt
  git add file.txt
  git commit -m "feature change" >/dev/null 2>&1

  run "$PREFLIGHT_SCRIPT" main
  teardown_git_repos
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OK" ]]
}

@test "preflight-check.sh: exits 1 when branch is BEHIND base" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  setup_git_repos

  # Create feature branch from clone-A
  cd "$TEST_CLONE_A"
  git checkout -b feature/test >/dev/null 2>&1
  echo "feature" >> file.txt
  git add file.txt
  git commit -m "feature change" >/dev/null 2>&1

  # Push a new commit to main from clone-B
  cd "$TEST_CLONE_B"
  echo "main advance" >> file.txt
  git add file.txt
  git commit -m "main advance" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  # Now feature branch in clone-A is behind
  cd "$TEST_CLONE_A"
  run "$PREFLIGHT_SCRIPT" main
  teardown_git_repos
  [ "$status" -eq 1 ]
  [[ "$output" =~ "behind" ]]
}

@test "preflight-check.sh: exits 1 when merge would conflict" {
  PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  setup_git_repos

  # Create feature branch modifying file.txt
  cd "$TEST_CLONE_A"
  git checkout -b feature/test >/dev/null 2>&1
  echo "feature version" > file.txt
  git add file.txt
  git commit -m "feature change" >/dev/null 2>&1

  # Push conflicting change to main from clone-B
  cd "$TEST_CLONE_B"
  echo "main version" > file.txt
  git add file.txt
  git commit -m "conflicting main change" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  # Now feature branch has conflicts with main
  cd "$TEST_CLONE_A"
  run "$PREFLIGHT_SCRIPT" main
  teardown_git_repos
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Conflict" ]]
}

# ===== wait-for-merge.sh tests =====

@test "wait-for-merge.sh is executable" {
  WAIT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  [ -x "$WAIT_SCRIPT" ]
}

@test "wait-for-merge.sh has proper shebang" {
  WAIT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  head -n 1 "$WAIT_SCRIPT" | grep -q "^#!/usr/bin/env bash"
}

@test "wait-for-merge.sh uses set -euo pipefail" {
  WAIT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  grep -q "set -euo pipefail" "$WAIT_SCRIPT"
}

@test "wait-for-merge.sh documents exit codes" {
  WAIT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  grep -q "Exit codes:" "$WAIT_SCRIPT"
  grep -q "0 " "$WAIT_SCRIPT"
  grep -q "1 " "$WAIT_SCRIPT"
}

@test "wait-for-merge.sh uses gh pr checks --watch" {
  WAIT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  grep -q "gh pr checks --watch" "$WAIT_SCRIPT"
}

@test "wait-for-merge.sh does not use a polling sleep loop" {
  WAIT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  run grep -q "while.*sleep\|sleep.*while" "$WAIT_SCRIPT"
  [ "$status" -ne 0 ]
}
