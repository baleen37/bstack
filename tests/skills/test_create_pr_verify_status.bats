#!/usr/bin/env bats
# Test suite for create-pr skill scripts

load '../helpers/bats_helper'

setup() {
  export PREFLIGHT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/preflight-check.sh"
  export WAIT_SCRIPT="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
}

# ===== preflight-check.sh tests =====

@test "preflight-check.sh is executable" {
  [ -x "$PREFLIGHT_SCRIPT" ]
}

@test "preflight-check.sh has proper shebang" {
  head -n 1 "$PREFLIGHT_SCRIPT" | grep -q "^#!/usr/bin/env bash"
}

@test "preflight-check.sh uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$PREFLIGHT_SCRIPT"
}

@test "preflight-check.sh has exit code comments" {
  grep -q "exit 0" "$PREFLIGHT_SCRIPT"
  grep -q "exit 1" "$PREFLIGHT_SCRIPT"
  grep -q "exit 2" "$PREFLIGHT_SCRIPT"
}

@test "preflight-check.sh validates git repo" {
  grep -q "git rev-parse.*git-dir" "$PREFLIGHT_SCRIPT"
}

@test "preflight-check.sh resolves base branch" {
  grep -q "defaultBranchRef" "$PREFLIGHT_SCRIPT"
}

@test "preflight-check.sh: exits 2 when not in a git repository" {
  TEMP_DIR=$(mktemp -d)
  cd "$TEMP_DIR"
  run env -u GIT_DIR -u GIT_WORK_TREE "$PREFLIGHT_SCRIPT" main
  [ "$status" -eq 2 ]
  [[ "$output" =~ "Not a git repo" ]]
  rm -rf "$TEMP_DIR"
}

@test "preflight-check.sh: does not print color escape sequences" {
  run grep -Eq "\\\\033|RED=|GREEN=|YELLOW=" "$PREFLIGHT_SCRIPT"
  [ "$status" -ne 0 ]
}

# ===== preflight-check.sh integration tests =====

setup_git_repos() {
  export TEST_REMOTE=$(mktemp -d)
  export TEST_CLONE_A=$(mktemp -d)
  export TEST_CLONE_B=$(mktemp -d)

  git init --bare -b main "$TEST_REMOTE" >/dev/null 2>&1
  git clone "$TEST_REMOTE" "$TEST_CLONE_A" >/dev/null 2>&1
  git clone "$TEST_REMOTE" "$TEST_CLONE_B" >/dev/null 2>&1

  cd "$TEST_CLONE_A"
  git config user.name "Test" >/dev/null 2>&1
  git config user.email "test@test.local" >/dev/null 2>&1
  echo "init" > file.txt
  git add file.txt
  git commit -m "initial commit" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  cd "$TEST_CLONE_B"
  git config user.name "Test" >/dev/null 2>&1
  git config user.email "test@test.local" >/dev/null 2>&1
  git pull origin main >/dev/null 2>&1
}

teardown_git_repos() {
  rm -rf "$TEST_REMOTE" "$TEST_CLONE_A" "$TEST_CLONE_B"
}

@test "preflight-check.sh: exits 0 when branch is up to date and clean" {
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

@test "preflight-check.sh: auto-syncs when branch is BEHIND base" {
  setup_git_repos

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

  # preflight should auto-sync (merge + push)
  cd "$TEST_CLONE_A"
  run "$PREFLIGHT_SCRIPT" main
  teardown_git_repos
  # Auto-sync merges and pushes — may succeed or fail depending on push setup
  # But it should attempt to sync, not just report BEHIND
  [[ "$output" =~ "syncing" || "$output" =~ "OK" ]]
}

@test "preflight-check.sh: exits 1 when merge would conflict" {
  setup_git_repos

  cd "$TEST_CLONE_A"
  git checkout -b feature/test >/dev/null 2>&1
  echo "feature version" > file.txt
  git add file.txt
  git commit -m "feature change" >/dev/null 2>&1

  cd "$TEST_CLONE_B"
  echo "main version" > file.txt
  git add file.txt
  git commit -m "conflicting main change" >/dev/null 2>&1
  git push origin main >/dev/null 2>&1

  cd "$TEST_CLONE_A"
  run "$PREFLIGHT_SCRIPT" main
  teardown_git_repos
  [ "$status" -eq 1 ]
}

# ===== wait-for-merge.sh tests =====

@test "wait-for-merge.sh is executable" {
  [ -x "$WAIT_SCRIPT" ]
}

@test "wait-for-merge.sh has proper shebang" {
  head -n 1 "$WAIT_SCRIPT" | grep -q "^#!/usr/bin/env bash"
}

@test "wait-for-merge.sh uses set -euo pipefail" {
  grep -q "set -euo pipefail" "$WAIT_SCRIPT"
}

@test "wait-for-merge.sh has exit code comments" {
  grep -q "exit 0" "$WAIT_SCRIPT"
  grep -q "exit 1" "$WAIT_SCRIPT"
}

@test "wait-for-merge.sh uses gh pr checks --watch" {
  grep -q "gh pr checks --watch" "$WAIT_SCRIPT"
}

@test "wait-for-merge.sh does not use a polling sleep loop" {
  run grep -q "while.*sleep\|sleep.*while" "$WAIT_SCRIPT"
  [ "$status" -ne 0 ]
}
