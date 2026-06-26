#!/usr/bin/env bats
# create-pr e2e test - intentionally failing to test CI recovery flow

bats_require_minimum_version 1.5.0

setup() {
  TEST_TEMP_DIR="$(mktemp -d -t create-pr-test.XXXXXX)"
  export TEST_TEMP_DIR
  export STUB_LOG="${TEST_TEMP_DIR}/calls.log"
  export PATH="${TEST_TEMP_DIR}/bin:${PATH}"
  mkdir -p "${TEST_TEMP_DIR}/bin"
  touch "$STUB_LOG"

  cat > "${TEST_TEMP_DIR}/bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "git $*" >> "$STUB_LOG"
  case "$*" in
    "rev-parse --git-dir") echo ".git" ;;
    "rev-parse HEAD") echo "${GIT_HEAD_OID:-headoid000}" ;;
    "rev-parse --git-path create-pr-body.XXXXXX") echo "${TEST_TEMP_DIR}/git/create-pr-body.XXXXXX" ;;
    "rev-parse --show-toplevel") echo "${GIT_TOPLEVEL:-$TEST_TEMP_DIR}" ;;
    "symbolic-ref --short HEAD") echo "feature/create-pr-wrapper" ;;
    "fetch origin main") ;;
    "rev-list HEAD..origin/main --count") echo "${GIT_BEHIND:-0}" ;;
    "rev-list origin/main..HEAD --count") echo "${GIT_AHEAD:-1}" ;;
    "merge origin/main --no-edit")
      if [[ "${GIT_MERGE_CONFLICT:-0}" == "1" || "${GIT_MERGE_BLOCKED:-0}" == "1" ]]; then
        exit 1
      fi
      ;;
    "merge-tree --write-tree HEAD origin/main") ;;
    "status --porcelain") [[ "${GIT_DIRTY:-0}" == "1" ]] && echo " M changed.txt" || true ;;
    "diff --name-only --diff-filter=U") [[ "${GIT_MERGE_CONFLICT:-0}" == "1" ]] && echo "plugins/me/skills/create-pr/SKILL.md" || true ;;
    "add -- plugins/me/skills/create-pr/SKILL.md") touch "${TEST_TEMP_DIR}/staged" ;;
  "diff --cached --quiet") [[ -f "${TEST_TEMP_DIR}/staged" ]] && exit 1 || exit 0 ;;
  "commit -m feat(test): wrapper") rm -f "${TEST_TEMP_DIR}/staged"; touch "${TEST_TEMP_DIR}/committed" ;;
  "push -u origin HEAD") ;;
  "log -1 --pretty=%s") echo "feat(test): wrapper" ;;
  *) ;;
esac
STUB
	  chmod +x "${TEST_TEMP_DIR}/bin/git"

  cat > "${TEST_TEMP_DIR}/bin/sleep" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "sleep $*" >> "$STUB_LOG"
touch "${TEST_TEMP_DIR}/slept"
exit 0
STUB
  chmod +x "${TEST_TEMP_DIR}/bin/sleep"

	  cat > "${TEST_TEMP_DIR}/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "gh $*" >> "$STUB_LOG"

pr_visible() {
  [[ "${GH_EXISTING_PR:-none}" != "none" ]] && return 0
  [[ -f "${TEST_TEMP_DIR}/pr_created" ]] && return 0
  [[ "${GH_PR_VIEW_AFTER_CREATE_FAIL:-0}" == "1" && -f "${TEST_TEMP_DIR}/create_failed" ]]
}

case "$*" in
  "repo view --json defaultBranchRef -q .defaultBranchRef.name") echo "main" ;;
  "pr view --json state --jq .state")
    if [[ "${GH_MERGE_AFTER_FIRST_STATE:-0}" == "1" ]]; then
      if [[ -f "${TEST_TEMP_DIR}/state_seen" ]]; then
        echo "MERGED"
      else
        touch "${TEST_TEMP_DIR}/state_seen"
        echo "OPEN"
      fi
      exit 0
    fi
    if [[ "${GH_EXISTING_PR:-none}" == "merged" || -f "${TEST_TEMP_DIR}/merged" ]]; then
      echo "MERGED"
    elif [[ "${GH_EXISTING_PR:-none}" == "closed" ]]; then
      echo "CLOSED"
    elif [[ "${GH_EXISTING_PR:-none}" == "open" || -f "${TEST_TEMP_DIR}/pr_created" ]]; then
      echo "OPEN"
    elif [[ "${GH_PR_VIEW_AFTER_CREATE_FAIL:-0}" == "1" && -f "${TEST_TEMP_DIR}/create_failed" ]]; then
      echo "OPEN"
    else
      exit 1
    fi
    ;;
  "pr view --json url --jq .url")
    if pr_visible; then
      echo "https://example.test/pr/1"
    else
      exit 1
    fi
    ;;
  "pr view --json headRefOid --jq .headRefOid") echo "${GH_MERGED_HEAD_OID:-headoid000}" ;;
  "pr view --json url") pr_visible || exit 1 ;;
  "pr checks --json name,bucket,link")
    if [[ "${GH_CHECKS:-pass}" == "fail" ]]; then
      echo '[{"name":"CI","bucket":"fail","link":"https://example.test/actions/runs/9876543210/job/1"}]'
    elif [[ "${GH_CHECKS:-pass}" == "pending" ]]; then
      echo '[{"name":"CI","bucket":"pending","link":"https://example.test/actions/runs/1234567890"}]'
    elif [[ "${GH_CHECKS:-pass}" == "pending-then-fail" ]]; then
      if [[ -f "${TEST_TEMP_DIR}/slept" ]]; then
        echo '[{"name":"CI","bucket":"fail","link":"https://example.test/actions/runs/9876543210/job/1"}]'
      else
        echo '[{"name":"CI","bucket":"pending","link":"https://example.test/actions/runs/1234567890"}]'
      fi
    else
      echo '[{"name":"CI","bucket":"pass","link":"https://example.test/runs/1234567890"}]'
    fi
    ;;
  pr\ create*)
    if [[ "${GH_PR_CREATE_FAIL:-0}" == "1" ]]; then
      touch "${TEST_TEMP_DIR}/create_failed"
      exit 1
    fi
    touch "${TEST_TEMP_DIR}/pr_created"; echo "https://example.test/pr/1"
    ;;
  "pr merge --auto --squash") touch "${TEST_TEMP_DIR}/auto_merge"; echo "auto merge enabled" ;;
  "pr merge --squash")
    [[ "${GH_SQUASH_FAIL:-0}" == "1" ]] && exit 1
    touch "${TEST_TEMP_DIR}/merged"; echo "merged"
    ;;
  *) ;;
esac
STUB
  chmod +x "${TEST_TEMP_DIR}/bin/gh"
}

teardown() {
  rm -rf "$TEST_TEMP_DIR"
}

assert_log_excludes() {
  local pattern="$1"
  if grep -q "$pattern" "$STUB_LOG"; then
    echo "Unexpected command in log: $pattern" >&2
    cat "$STUB_LOG" >&2
    return 1
  fi
}

@test "create-pr: wait-for-merge script exists and is executable" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"
  [ -f "$script" ]
  [ -x "$script" ]
}

@test "create-pr: wait-for-merge reports CI failure with run id" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"

  run env GH_EXISTING_PR=open GH_CHECKS=fail "$script"

  [ "$status" -eq 1 ]
  [[ "$output" == *"check: CI: fail"* ]]
  [[ "$output" == *"CI_FAILED: https://example.test/pr/1 run-id=9876543210"* ]]
  assert_log_excludes "gh pr merge --squash"
}

@test "create-pr: wait-for-merge reports awaiting review when squash merge is blocked" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"

  run env GH_EXISTING_PR=open GH_SQUASH_FAIL=1 "$script"

  [ "$status" -eq 0 ]
  [[ "$output" == *"check: CI: pass"* ]]
  [[ "$output" == *"AWAITING_REVIEW: https://example.test/pr/1"* ]]
}

@test "create-pr: wait-for-merge stops on closed PR" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"

  run env GH_EXISTING_PR=closed "$script"

  [ "$status" -eq 1 ]
  [[ "$output" == "CLOSED: https://example.test/pr/1" ]]
  assert_log_excludes "gh pr checks"
}
