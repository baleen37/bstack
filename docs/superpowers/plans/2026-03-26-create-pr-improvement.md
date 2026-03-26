# create-pr Skill Improvement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `check-conflicts.sh` with a broader `preflight-check.sh`, add `wait-for-merge.sh`, and simplify SKILL.md from 8 steps to 5.

**Architecture:** Two new shell scripts replace the existing conflict check and post-PR wait logic. `preflight-check.sh` runs before push (BEHIND + conflict + advisory branch protection). `wait-for-merge.sh` runs after PR creation, blocking until merge or failure using `gh pr checks --watch`. SKILL.md is rewritten to use the new 5-step flow.

**Tech Stack:** bash, gh CLI, git, bats (testing)

**Prerequisites:** Git 2.38+ (for `git merge-tree` exit code behavior)

---

## File Map

| File | Action |
|------|--------|
| `plugins/me/skills/create-pr/scripts/preflight-check.sh` | Create (replaces check-conflicts.sh) |
| `plugins/me/skills/create-pr/scripts/check-conflicts.sh` | Delete |
| `plugins/me/skills/create-pr/scripts/wait-for-merge.sh` | Create |
| `plugins/me/skills/create-pr/SKILL.md` | Modify |
| `tests/skills/test_check_conflicts.bats` | Delete |
| `tests/skills/test_create_pr_verify_status.bats` | Modify (add preflight + wait-for-merge tests) |

---

### Task 1: Write failing tests for preflight-check.sh

**Files:**
- Modify: `tests/skills/test_create_pr_verify_status.bats`

- [ ] **Step 1: Add preflight-check.sh tests to existing test file**

Open `tests/skills/test_create_pr_verify_status.bats` and append the following tests at the end of the file (after the last existing test):

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail (scripts don't exist yet)**

```bash
bats tests/skills/test_create_pr_verify_status.bats
```

Expected: multiple FAIL lines for preflight-check.sh and wait-for-merge.sh tests

- [ ] **Step 3: Commit failing tests**

```bash
git add tests/skills/test_create_pr_verify_status.bats
git commit -m "test(create-pr): add failing tests for preflight-check and wait-for-merge"
```

---

### Task 2: Create preflight-check.sh

**Files:**
- Create: `plugins/me/skills/create-pr/scripts/preflight-check.sh`

- [ ] **Step 1: Create the script**

```bash
cat > plugins/me/skills/create-pr/scripts/preflight-check.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# preflight-check.sh - Pre-push checks: BEHIND, conflicts, branch protection (advisory)
# Usage: preflight-check.sh [base-branch]
#
# Exit codes:
#   0 - All blocking checks passed (may have advisory warnings)
#   1 - Blocking issue found (BEHIND or conflict)
#   2 - Environment error (not a git repo, gh not authenticated, etc.)

BASE="${1:-}"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: Not in a git repository" >&2
  exit 2
fi

if [[ -z "$BASE" ]]; then
  BASE=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)
fi
if [[ -z "$BASE" ]]; then
  echo "ERROR: Cannot determine default branch" >&2
  echo "  - Pass base branch explicitly: $0 <base-branch>" >&2
  echo "  - Or ensure 'gh' CLI is authenticated" >&2
  exit 2
fi

if ! git fetch origin "$BASE" >/dev/null 2>&1; then
  echo "ERROR: Failed to fetch origin/$BASE" >&2
  echo "  - Check if remote 'origin' exists: git remote -v" >&2
  echo "  - Check if branch '$BASE' exists on remote" >&2
  exit 2
fi

# --- Check 1: BEHIND ---
BEHIND_COUNT=$(git rev-list HEAD..origin/"$BASE" --count 2>/dev/null || echo "0")
if [[ "$BEHIND_COUNT" -gt 0 ]]; then
  echo "ERROR: Branch is $BEHIND_COUNT commit(s) behind origin/$BASE" >&2
  echo "  Sync with base before pushing:" >&2
  echo "    git fetch origin $BASE && git merge origin/$BASE" >&2
  exit 1
fi

# --- Check 2: Conflicts ---
MERGE_BASE=$(git merge-base HEAD "origin/$BASE" 2>/dev/null || echo "")
if [[ -z "$MERGE_BASE" ]]; then
  echo "ERROR: Cannot find common ancestor with origin/$BASE" >&2
  exit 2
fi

if ! MERGE_OUTPUT=$(git merge-tree "$MERGE_BASE" HEAD "origin/$BASE" 2>&1); then
  echo "ERROR: Conflicts detected with origin/$BASE" >&2
  echo "Resolution steps:" >&2
  echo "  1. git fetch origin $BASE" >&2
  echo "  2. git merge origin/$BASE" >&2
  echo "  3. Resolve conflicts" >&2
  echo "  4. git add <resolved-files>" >&2
  echo "  5. git commit" >&2
  if echo "$MERGE_OUTPUT" | grep -q "CONFLICT"; then
    echo "Conflicts:" >&2
    echo "$MERGE_OUTPUT" | grep "CONFLICT" | sed 's/^/  - /' >&2
  fi
  exit 1
fi

# --- Check 3: Branch protection (advisory only) ---
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [[ -n "$REPO" ]]; then
  PROTECTION=$(gh api "repos/$REPO/branches/$BASE/protection" 2>/dev/null || true)
  if [[ -n "$PROTECTION" ]]; then
    REQUIRED_REVIEWERS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0' 2>/dev/null || echo "0")
    REQUIRED_CHECKS=$(echo "$PROTECTION" | jq -r '.required_status_checks.contexts // [] | length' 2>/dev/null || echo "0")
    if [[ "$REQUIRED_REVIEWERS" -gt 0 || "$REQUIRED_CHECKS" -gt 0 ]]; then
      echo "INFO: Branch protection on $BASE:"
      if [[ "$REQUIRED_REVIEWERS" -gt 0 ]]; then
        echo "  - Required approvals: $REQUIRED_REVIEWERS"
      fi
      if [[ "$REQUIRED_CHECKS" -gt 0 ]]; then
        echo "  - Required CI checks: $REQUIRED_CHECKS"
        echo "$PROTECTION" | jq -r '.required_status_checks.contexts[]' 2>/dev/null | sed 's/^/    - /' || true
      fi
    fi
  fi
fi

echo "OK: Pre-flight checks passed"
echo "  - Branch is up to date with origin/$BASE"
echo "  - No merge conflicts detected"
exit 0
EOF
chmod +x plugins/me/skills/create-pr/scripts/preflight-check.sh
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
bats tests/skills/test_create_pr_verify_status.bats
```

Expected: all preflight-check.sh tests PASS

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/create-pr/scripts/preflight-check.sh
git commit -m "feat(create-pr): add preflight-check.sh replacing check-conflicts.sh"
```

---

### Task 3: Create wait-for-merge.sh

**Files:**
- Create: `plugins/me/skills/create-pr/scripts/wait-for-merge.sh`

- [ ] **Step 1: Create the script**

```bash
cat > plugins/me/skills/create-pr/scripts/wait-for-merge.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# wait-for-merge.sh - Wait for PR CI to complete and confirm merge
# Usage: wait-for-merge.sh
#
# Assumes: PR exists for current branch, auto-merge is already enabled
#
# Exit codes:
#   0 - PR merged successfully, or CI passed and awaiting review approval
#   1 - PR closed without merge, or CI failed

PR_INFO=$(gh pr view --json url,state 2>/dev/null || true)
if [[ -z "$PR_INFO" ]]; then
  echo "ERROR: No open PR found for current branch" >&2
  echo "  - Create a PR first: gh pr create" >&2
  exit 1
fi

PR_URL=$(echo "$PR_INFO" | jq -r .url)
PR_STATE=$(echo "$PR_INFO" | jq -r .state)

if [[ "$PR_STATE" == "MERGED" ]]; then
  echo ""
  echo "✓ PR already merged"
  echo "  - URL: $PR_URL"
  exit 0
fi

if [[ "$PR_STATE" == "CLOSED" ]]; then
  echo ""
  echo "✗ PR was closed without merging"
  echo "  - URL: $PR_URL"
  exit 1
fi

echo "Waiting for CI checks to complete..."
echo "  - URL: $PR_URL"

# Block until all CI checks finish (pass or fail)
if ! gh pr checks --watch 2>&1; then
  echo "" >&2
  echo "✗ CI checks failed" >&2
  echo "  - Fix CI failures and push again" >&2
  echo "  - Monitor: gh pr checks $PR_URL" >&2
  exit 1
fi

# Single state check after CI completes
FINAL_STATE=$(gh pr view --json state -q .state)

if [[ "$FINAL_STATE" == "MERGED" ]]; then
  echo ""
  echo "✓ PR merged successfully"
  echo "  - URL: $PR_URL"
  exit 0
fi

if [[ "$FINAL_STATE" == "OPEN" ]]; then
  echo ""
  echo "✓ CI passed. PR awaiting review approval."
  echo "  - URL: $PR_URL"
  echo "  - Auto-merge is enabled — PR will merge after approval"
  exit 0
fi

echo "" >&2
echo "✗ PR not merged (state: $FINAL_STATE)" >&2
echo "  - URL: $PR_URL" >&2
echo "  - Check: gh pr view" >&2
exit 1
EOF
chmod +x plugins/me/skills/create-pr/scripts/wait-for-merge.sh
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
bats tests/skills/test_create_pr_verify_status.bats
```

Expected: all wait-for-merge.sh tests PASS

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/create-pr/scripts/wait-for-merge.sh
git commit -m "feat(create-pr): add wait-for-merge.sh for post-PR merge completion"
```

---

### Task 4: Delete check-conflicts.sh and its test file

**Files:**
- Delete: `plugins/me/skills/create-pr/scripts/check-conflicts.sh`
- Delete: `tests/skills/test_check_conflicts.bats`

- [ ] **Step 1: Delete the files**

```bash
git rm plugins/me/skills/create-pr/scripts/check-conflicts.sh
git rm tests/skills/test_check_conflicts.bats
```

- [ ] **Step 2: Run full test suite to confirm nothing breaks**

```bash
bats tests/skills/
```

Expected: all tests PASS (no references to check-conflicts.sh remain)

- [ ] **Step 3: Commit**

```bash
git commit -m "remove(create-pr): delete check-conflicts.sh and its test file"
```

---

### Task 5: Update SKILL.md to 5-step flow

**Files:**
- Modify: `plugins/me/skills/create-pr/SKILL.md`

- [ ] **Step 1: Replace SKILL.md content**

Replace the `## Overview` line in `plugins/me/skills/create-pr/SKILL.md`:

```markdown
Full PR flow: pre-flight → commit → push → PR creation → wait-for-merge.

If wait-for-merge reports a failure, use `me:pr-pass` to fix it.
```

Replace the entire `## Workflow` section with:

```markdown
## Workflow

```bash
# 1) pre-flight (run in parallel: git status, git branch --show-current, git log --oneline -5)
# If on main/master: automatically create a branch from the last commit message
#   git checkout -b <type>/<short-description>  (derived from commit subject)
# Never ask the user — just create it.
# Then run preflight check (blocking):
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/preflight-check.sh"

# 2) commit
git add <specific-files>
git commit -m "type(scope): summary"

# 3) push
git push -u origin HEAD

# 4) detect PR template (check in order)
# .github/PULL_REQUEST_TEMPLATE.md → PULL_REQUEST_TEMPLATE.md → default format
# If found: read it, fill each section with actual change details, preserve empty checkboxes (- [ ]) as-is
# If not found: use default format (see PR Body Format below)
# Then create PR and enable auto-merge:
gh pr create --title "$(git log -1 --pretty=%s)" --body "<filled body>"
gh pr merge --auto --squash || gh pr merge --squash

# 5) wait for merge
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/wait-for-merge.sh"
# exit 0: merged (or CI passed, awaiting review) — done
# exit 1: failed — use me:pr-pass, STOP
```
```

Also update the `## Stop Conditions` section — remove "Conflict check failed" and replace with:

```markdown
## Stop Conditions

- No changes to commit and no unpushed commits
- Pre-flight check failed (BEHIND or conflicts)
- Required CI failed
- State-changing follow-up not approved by user
```

- [ ] **Step 2: Run all tests**

```bash
bats tests/skills/
```

Expected: all tests PASS

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/create-pr/SKILL.md
git commit -m "feat(create-pr): simplify workflow to 5 steps, use preflight-check and wait-for-merge"
```

---

## Self-Review

**Spec coverage:**
- ✓ preflight-check.sh: BEHIND + conflict + advisory branch protection
- ✓ wait-for-merge.sh: `gh pr checks --watch` + single state check, no polling loop
- ✓ wait-for-merge.sh: OPEN state handled as success (review awaiting)
- ✓ check-conflicts.sh deleted
- ✓ SKILL.md 8 → 5 steps (Overview line also updated)
- ✓ verify-pr-status.sh retained (untouched, for pr-pass)
- ✓ auto-merge fallback preserved (`--auto --squash || --squash`)
- ✓ Integration tests for preflight-check.sh (BEHIND, conflict, clean scenarios)
- ✓ Git 2.38+ prerequisite documented

**Placeholder scan:** None found.

**Type consistency:** All script paths use `${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/` consistently.
