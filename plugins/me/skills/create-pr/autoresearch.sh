#!/usr/bin/env bash
set -euo pipefail

# autoresearch.sh — Composite quality score for create-pr skill
# Outputs METRIC lines for autoresearch loop

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$SCRIPT_DIR"
SCRIPTS_DIR="$SKILL_DIR/scripts"
REPO_ROOT="$(cd "$SKILL_DIR/../../../.." && pwd)"
TEST_FILE="$REPO_ROOT/tests/skills/test_create_pr_verify_status.bats"
SKILL_MD="$SKILL_DIR/SKILL.md"

score=0
max_score=0

# --- 1. ShellCheck (max 20 points) ---
max_score=$((max_score + 20))
shellcheck_warnings=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  warnings=$(shellcheck -x --source-path="$SCRIPTS_DIR" -f json "$script" 2>/dev/null | jq 'length' || echo "0")
  shellcheck_warnings=$((shellcheck_warnings + warnings))
done
if [[ $shellcheck_warnings -eq 0 ]]; then
  score=$((score + 20))
elif [[ $shellcheck_warnings -le 3 ]]; then
  score=$((score + 12))
elif [[ $shellcheck_warnings -le 10 ]]; then
  score=$((score + 4))
fi

# --- 2. BATS Tests (max 20 points) ---
max_score=$((max_score + 20))
if [[ -f "$TEST_FILE" ]]; then
  test_output=$(bats "$TEST_FILE" 2>&1 || true)
  total_tests=$(echo "$test_output" | head -1 | sed 's/1\.\.//')
  passed_tests=$(echo "$test_output" | grep -c "^ok " || true)
  if [[ $total_tests -gt 0 ]]; then
    test_pass_rate=$(( (passed_tests * 100) / total_tests ))
    test_points=$(( (passed_tests * 20) / total_tests ))
    score=$((score + test_points))
  else
    test_pass_rate=0
  fi
else
  total_tests=0
  passed_tests=0
  test_pass_rate=0
fi

# --- 3. Code Quality (max 20 points) ---
max_score=$((max_score + 20))
code_quality=0

# 3a. Error messages go to stderr (4 points)
stderr_score=0
stderr_total=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  error_lines=$(grep -c 'echo.*"ERROR:' "$script" 2>/dev/null || true)
  stderr_lines=$(grep -c 'echo.*"ERROR:.*>&2' "$script" 2>/dev/null || true)
  stderr_total=$((stderr_total + error_lines))
  stderr_score=$((stderr_score + stderr_lines))
done
if [[ $stderr_total -gt 0 && $stderr_score -eq $stderr_total ]]; then
  code_quality=$((code_quality + 4))
elif [[ $stderr_total -eq 0 ]]; then
  code_quality=$((code_quality + 4))
fi

# 3b. All scripts have usage comments (4 points)
usage_count=0
script_count=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  script_count=$((script_count + 1))
  if grep -q "^# Usage:" "$script" 2>/dev/null; then
    usage_count=$((usage_count + 1))
  fi
done
if [[ $script_count -gt 0 && $usage_count -eq $script_count ]]; then
  code_quality=$((code_quality + 4))
fi

# 3c. All scripts document exit codes (4 points)
exitcode_count=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  if grep -q "Exit codes:" "$script" 2>/dev/null; then
    exitcode_count=$((exitcode_count + 1))
  fi
done
if [[ $script_count -gt 0 && $exitcode_count -eq $script_count ]]; then
  code_quality=$((code_quality + 4))
fi

# 3d. No hardcoded branch names (4 points)
hardcoded=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  if grep -E '^\s*(BASE|base)="(main|master)"' "$script" 2>/dev/null | grep -v "^#" >/dev/null; then
    hardcoded=$((hardcoded + 1))
  fi
done
if [[ $hardcoded -eq 0 ]]; then
  code_quality=$((code_quality + 4))
fi

# 3e. All error/failure messages go to stderr (4 points)
non_stderr_errors=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  error_no_stderr=$(grep -E 'echo.*"(ERROR:|✗)' "$script" 2>/dev/null | grep -cv '>&2' || true)
  non_stderr_errors=$((non_stderr_errors + error_no_stderr))
done
if [[ $non_stderr_errors -eq 0 ]]; then
  code_quality=$((code_quality + 4))
fi

score=$((score + code_quality))

# --- 4. SKILL.md Quality (max 20 points) ---
max_score=$((max_score + 20))
skillmd_quality=0

if [[ -f "$SKILL_MD" ]]; then
  # 4a. Has YAML frontmatter with name and description (4 points)
  if head -20 "$SKILL_MD" | grep -q "^---" && grep -q "^name:" "$SKILL_MD" && grep -q "^description:" "$SKILL_MD"; then
    skillmd_quality=$((skillmd_quality + 4))
  fi

  # 4b. Has required sections: Overview, When to Use, Workflow (4 points)
  sections=0
  grep -q "^## Overview" "$SKILL_MD" && sections=$((sections + 1))
  grep -q "^## When to Use" "$SKILL_MD" && sections=$((sections + 1))
  grep -q "^## Workflow" "$SKILL_MD" && sections=$((sections + 1))
  if [[ $sections -eq 3 ]]; then
    skillmd_quality=$((skillmd_quality + 4))
  elif [[ $sections -ge 2 ]]; then
    skillmd_quality=$((skillmd_quality + 2))
  fi

  # 4c. Has stop conditions (4 points)
  if grep -q "^## Stop Conditions" "$SKILL_MD" || grep -q "^## Stop" "$SKILL_MD"; then
    skillmd_quality=$((skillmd_quality + 4))
  fi

  # 4d. References all script paths (4 points)
  script_refs=0
  grep -q "preflight-check" "$SKILL_MD" && script_refs=$((script_refs + 1))
  grep -q "wait-for-merge" "$SKILL_MD" && script_refs=$((script_refs + 1))
  grep -q "verify-pr-status\|sync-with-base" "$SKILL_MD" && script_refs=$((script_refs + 1))
  if [[ $script_refs -ge 3 ]]; then
    skillmd_quality=$((skillmd_quality + 4))
  elif [[ $script_refs -ge 2 ]]; then
    skillmd_quality=$((skillmd_quality + 3))
  elif [[ $script_refs -ge 1 ]]; then
    skillmd_quality=$((skillmd_quality + 1))
  fi

  # 4e. Has error handling guidance (4 points)
  if grep -qi "error\|fail\|exit" "$SKILL_MD" && grep -qi "pr-pass\|fix\|resolve" "$SKILL_MD"; then
    skillmd_quality=$((skillmd_quality + 4))
  fi
fi

score=$((score + skillmd_quality))

# --- 5. DRY & Test Depth (max 20 points) ---
max_score=$((max_score + 20))
advanced_quality=0

# 5a. Code deduplication: base branch detection pattern (5 points)
# Count how many scripts have the full base-branch-detection boilerplate
base_detect_scripts=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  if grep -q 'gh repo view --json defaultBranchRef' "$script" 2>/dev/null; then
    base_detect_scripts=$((base_detect_scripts + 1))
  fi
done
# If shared helper exists or <=1 script has the pattern, it's DRY
if [[ -f "$SCRIPTS_DIR/common.sh" ]] || [[ -f "$SCRIPTS_DIR/lib.sh" ]]; then
  advanced_quality=$((advanced_quality + 5))
elif [[ $base_detect_scripts -le 1 ]]; then
  advanced_quality=$((advanced_quality + 5))
elif [[ $base_detect_scripts -le 2 ]]; then
  advanced_quality=$((advanced_quality + 3))
else
  advanced_quality=$((advanced_quality + 0))
fi

# 5b. Test depth: at least 5 tests per script (5 points)
# Count tests mentioning each script
test_depth_score=0
if [[ -f "$TEST_FILE" ]]; then
  for script_name in preflight-check verify-pr-status wait-for-merge sync-with-base; do
    test_count=$(grep -c "$script_name" "$TEST_FILE" 2>/dev/null || true)
    if [[ $test_count -ge 5 ]]; then
      test_depth_score=$((test_depth_score + 1))
    fi
  done
fi
# 4 scripts well-tested = 5 pts, 3 = 4 pts, 2 = 3 pts, 1 = 1 pt
case $test_depth_score in
  4) advanced_quality=$((advanced_quality + 5)) ;;
  3) advanced_quality=$((advanced_quality + 4)) ;;
  2) advanced_quality=$((advanced_quality + 3)) ;;
  1) advanced_quality=$((advanced_quality + 1)) ;;
esac

# 5c. All non-zero exit paths have descriptive messages (5 points)
missing_exit_msg=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  # Find "exit [1-9]" lines and check if preceded by an echo within 3 lines
  while IFS= read -r line_num; do
    # Check if any echo exists in the 3 lines before this exit
    start=$((line_num - 3))
    [[ $start -lt 1 ]] && start=1
    context=$(sed -n "${start},${line_num}p" "$script")
    if ! echo "$context" | grep -q 'echo'; then
      missing_exit_msg=$((missing_exit_msg + 1))
    fi
  done < <(grep -n 'exit [1-9]' "$script" 2>/dev/null | cut -d: -f1)
done
if [[ $missing_exit_msg -eq 0 ]]; then
  advanced_quality=$((advanced_quality + 5))
elif [[ $missing_exit_msg -le 2 ]]; then
  advanced_quality=$((advanced_quality + 3))
fi

# 5d. SKILL.md references error recovery for each failure mode (5 points)
if [[ -f "$SKILL_MD" ]]; then
  recovery_refs=0
  grep -qi "behind\|BEHIND" "$SKILL_MD" && recovery_refs=$((recovery_refs + 1))
  grep -qi "conflict" "$SKILL_MD" && recovery_refs=$((recovery_refs + 1))
  grep -qi "ci.*fail\|CI.*fail\|check.*fail" "$SKILL_MD" && recovery_refs=$((recovery_refs + 1))
  case $recovery_refs in
    3) advanced_quality=$((advanced_quality + 5)) ;;
    2) advanced_quality=$((advanced_quality + 3)) ;;
    1) advanced_quality=$((advanced_quality + 1)) ;;
  esac
fi

score=$((score + advanced_quality))

# --- Output Metrics ---
echo "METRIC quality_score=$score"
echo "METRIC shellcheck_warnings=$shellcheck_warnings"
echo "METRIC test_pass_rate=${test_pass_rate:-0}"
echo "METRIC code_quality=$code_quality"
echo "METRIC skillmd_quality=$skillmd_quality"
echo "METRIC advanced_quality=$advanced_quality"
echo "METRIC total_tests=${total_tests:-0}"
echo "METRIC max_score=$max_score"
