#!/usr/bin/env bats
# create-pr e2e test - intentionally failing to test CI recovery flow

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

@test "create-pr: wrapper commits selected files, creates PR, enables auto merge, and waits" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"
  local body="${TEST_TEMP_DIR}/pr_body.md"

  run env CREATE_PR_BODY_PATH="$body" bash -c \
    "printf '## Summary\n- wrapper\n' | '$script' --auto-merge 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"MERGED: https://example.test/pr/1"* ]]
  [ "$(cat "$body")" = $'## Summary\n- wrapper' ]
  grep -q "git add -- plugins/me/skills/create-pr/SKILL.md" "$STUB_LOG"
  grep -q "git commit -m feat(test): wrapper" "$STUB_LOG"
  grep -q "git push -u origin HEAD" "$STUB_LOG"
  grep -q "gh pr create --title feat(test): wrapper --body-file $body" "$STUB_LOG"
  grep -q "gh pr merge --auto --squash" "$STUB_LOG"
  grep -q "gh pr merge --squash" "$STUB_LOG"
}

@test "create-pr: wrapper uses a unique repo-local body file per run" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run bash -c \
    "printf '## Summary\n- wrapper\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  rm -f "${TEST_TEMP_DIR}/pr_created" "${TEST_TEMP_DIR}/committed"

  run bash -c \
    "printf '## Summary\n- wrapper 2\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  mapfile -t body_files < <(grep -Eo "${TEST_TEMP_DIR}/git/create-pr-body\\.[[:alnum:]]+" "$STUB_LOG" | sort -u)
  [ "${#body_files[@]}" -eq 2 ]
}

@test "create-pr: wrapper creates PR for existing committed branch diff without staged changes" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GIT_AHEAD=1 bash -c \
    "printf '## Summary\n- committed\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  grep -q "git push -u origin HEAD" "$STUB_LOG"
  grep -q "gh pr create --title feat(test): wrapper" "$STUB_LOG"
}

@test "create-pr: wrapper stops before PR creation when preflight reports no diff" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GIT_AHEAD=0 GIT_DIRTY=0 bash -c \
    "printf '## Summary\n- noop\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  [[ "$output" == "NOOP:"* ]]
  assert_log_excludes "git push -u origin HEAD"
  assert_log_excludes "gh pr create"
}

@test "create-pr: terminal MERGED only when HEAD matches the merged PR tip" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GH_EXISTING_PR=merged GIT_HEAD_OID=headoid000 GH_MERGED_HEAD_OID=headoid000 bash -c \
    "printf '## Summary\n- noop\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"MERGED: https://example.test/pr/1"* ]]
  assert_log_excludes "gh pr create"
}

@test "create-pr: creates a new PR when commits exist after the branch was merged" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GH_EXISTING_PR=merged GIT_HEAD_OID=newoid111 GH_MERGED_HEAD_OID=headoid000 GIT_AHEAD=1 bash -c \
    "printf '## Summary\n- post-merge work\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  [[ "$output" != *"MERGED:"* ]]
  grep -q "git push -u origin HEAD" "$STUB_LOG"
}

@test "create-pr: reuses existing open PR and auto-merges when requested" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GH_EXISTING_PR=open bash -c \
    "printf '## Summary\n- existing\n' | '$script' --auto-merge 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"PR_EXISTS: https://example.test/pr/1"* ]]
  [[ "$output" == *"MERGED: https://example.test/pr/1"* ]]
  assert_log_excludes "gh pr create"
  grep -q "gh pr merge --auto --squash" "$STUB_LOG"
}

@test "create-pr: syncs a branch behind base before continuing" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GIT_BEHIND=1 bash -c \
    "printf '## Summary\n- sync\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Behind base"* ]]
  grep -q "git merge origin/main --no-edit" "$STUB_LOG"
  grep -q "git push -u origin HEAD" "$STUB_LOG"
  grep -q "gh pr create --title feat(test): wrapper" "$STUB_LOG"
}

@test "create-pr: stops on base sync conflict before staging or PR creation" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GIT_BEHIND=1 GIT_MERGE_CONFLICT=1 bash -c \
    "printf '## Summary\n- conflict\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Behind base"* ]]
  [[ "$output" == *"plugins/me/skills/create-pr/SKILL.md"* ]]
  assert_log_excludes "git add --"
  assert_log_excludes "gh pr create"
}

@test "create-pr: stops on dirty merge block before staging or PR creation" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GIT_BEHIND=1 GIT_MERGE_BLOCKED=1 bash -c \
    "printf '## Summary\n- dirty\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Behind base"* ]]
  [[ "$output" == *"ERROR: merge blocked; check git status --short"* ]]
  assert_log_excludes "git add --"
  assert_log_excludes "gh pr create"
}

@test "create-pr: falls back to existing PR when gh pr create loses a race" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GH_PR_CREATE_FAIL=1 GH_PR_VIEW_AFTER_CREATE_FAIL=1 bash -c \
    "printf '## Summary\n- race\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  [[ "$output" == *"https://example.test/pr/1"* ]]
  grep -q "gh pr create --title feat(test): wrapper" "$STUB_LOG"
}

@test "create-pr: fails clearly when gh pr create fails and no PR exists" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run env GH_PR_CREATE_FAIL=1 bash -c \
    "printf '## Summary\n- create fail\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 1 ]
  [[ "$output" == *"PR create failed; no existing PR found."* ]]
  assert_log_excludes "gh pr merge --auto --squash"
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

@test "create-pr: wait-for-merge reports merged even when a status remains pending" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/wait-for-merge.sh"

  run env GH_EXISTING_PR=open GH_CHECKS=pending-then-fail GH_MERGE_AFTER_FIRST_STATE=1 "$script"

  [ "$status" -eq 0 ]
  [[ "$output" == "MERGED: https://example.test/pr/1" ]]
  assert_log_excludes "sleep 30"
}

@test "fix-pr: skill exists under the new name" {
  local skill="${BATS_TEST_DIRNAME}/../../plugins/me/skills/fix-pr/SKILL.md"

  [ -f "$skill" ]
}
