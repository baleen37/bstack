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
    "rev-parse --git-path create-pr-body.XXXXXX") echo "${TEST_TEMP_DIR}/git/create-pr-body.XXXXXX" ;;
    "symbolic-ref --short HEAD") echo "feature/create-pr-wrapper" ;;
  "fetch origin main") ;;
  "rev-list HEAD..origin/main --count") echo "${GIT_BEHIND:-0}" ;;
  "rev-list origin/main..HEAD --count") echo "${GIT_AHEAD:-1}" ;;
  "merge-tree --write-tree HEAD origin/main") ;;
  "status --porcelain") [[ "${GIT_DIRTY:-0}" == "1" ]] && echo " M changed.txt" || true ;;
  "add -- plugins/me/skills/create-pr/SKILL.md") touch "${TEST_TEMP_DIR}/staged" ;;
  "diff --cached --quiet") [[ -f "${TEST_TEMP_DIR}/staged" ]] && exit 1 || exit 0 ;;
  "commit -m feat(test): wrapper") rm -f "${TEST_TEMP_DIR}/staged"; touch "${TEST_TEMP_DIR}/committed" ;;
  "push -u origin HEAD") ;;
  "log -1 --pretty=%s") echo "feat(test): wrapper" ;;
  *) ;;
esac
STUB
  chmod +x "${TEST_TEMP_DIR}/bin/git"

  cat > "${TEST_TEMP_DIR}/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "gh $*" >> "$STUB_LOG"
case "$*" in
  "repo view --json defaultBranchRef -q .defaultBranchRef.name") echo "main" ;;
  "pr view --json state --jq .state")
    if [[ "${GH_EXISTING_PR:-none}" == "merged" || -f "${TEST_TEMP_DIR}/merged" ]]; then
      echo "MERGED"
    elif [[ "${GH_EXISTING_PR:-none}" == "open" || -f "${TEST_TEMP_DIR}/pr_created" ]]; then
      echo "OPEN"
    else
      exit 1
    fi
    ;;
  "pr view --json url --jq .url")
    if [[ "${GH_EXISTING_PR:-none}" != "none" || -f "${TEST_TEMP_DIR}/pr_created" ]]; then
      echo "https://example.test/pr/1"
    else
      exit 1
    fi
    ;;
  "pr view --json url") [[ "${GH_EXISTING_PR:-none}" != "none" || -f "${TEST_TEMP_DIR}/pr_created" ]] || exit 1 ;;
  "pr checks --json name,bucket,link") echo '[{"name":"CI","bucket":"pass","link":"https://example.test/runs/1234567890"}]' ;;
  pr\ create*) touch "${TEST_TEMP_DIR}/pr_created"; echo "https://example.test/pr/1" ;;
  "pr merge --auto --squash") touch "${TEST_TEMP_DIR}/auto_merge"; echo "auto merge enabled" ;;
  "pr merge --squash") touch "${TEST_TEMP_DIR}/merged"; echo "merged" ;;
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

@test "create-pr: wrapper uses unique repo-local body file by default" {
  local script="${BATS_TEST_DIRNAME}/../../plugins/me/skills/create-pr/scripts/create-pr.sh"

  run bash -c \
    "printf '## Summary\n- wrapper\n' | '$script' 'feat(test): wrapper' -- plugins/me/skills/create-pr/SKILL.md"

  [ "$status" -eq 0 ]
  grep -Eq "gh pr create --title feat\\(test\\): wrapper --body-file ${TEST_TEMP_DIR}/git/create-pr-body\\.[[:alnum:]]+" "$STUB_LOG"
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

@test "fix-pr: skill exists under the new name" {
  local skill="${BATS_TEST_DIRNAME}/../../plugins/me/skills/fix-pr/SKILL.md"

  [ -f "$skill" ]
}
