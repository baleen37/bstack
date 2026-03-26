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

# --- 1. ShellCheck (max 25 points) ---
max_score=$((max_score + 25))
shellcheck_warnings=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  warnings=$(shellcheck -f json "$script" 2>/dev/null | jq 'length' || echo "0")
  shellcheck_warnings=$((shellcheck_warnings + warnings))
done
if [[ $shellcheck_warnings -eq 0 ]]; then
  score=$((score + 25))
elif [[ $shellcheck_warnings -le 3 ]]; then
  score=$((score + 15))
elif [[ $shellcheck_warnings -le 10 ]]; then
  score=$((score + 5))
fi

# --- 2. BATS Tests (max 25 points) ---
max_score=$((max_score + 25))
if [[ -f "$TEST_FILE" ]]; then
  test_output=$(bats "$TEST_FILE" 2>&1 || true)
  total_tests=$(echo "$test_output" | head -1 | sed 's/1\.\.//')
  passed_tests=$(echo "$test_output" | grep -c "^ok " || true)
  if [[ $total_tests -gt 0 ]]; then
    test_pass_rate=$(( (passed_tests * 100) / total_tests ))
    test_points=$(( (passed_tests * 25) / total_tests ))
    score=$((score + test_points))
  else
    test_pass_rate=0
  fi
else
  total_tests=0
  passed_tests=0
  test_pass_rate=0
fi

# --- 3. Code Quality (max 25 points) ---
max_score=$((max_score + 25))
code_quality=0

# 3a. Error messages go to stderr (5 points)
stderr_score=0
stderr_total=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  error_lines=$(grep -c 'echo.*ERROR' "$script" 2>/dev/null || true)
  stderr_lines=$(grep -c 'echo.*ERROR.*>&2' "$script" 2>/dev/null || true)
  stderr_total=$((stderr_total + error_lines))
  stderr_score=$((stderr_score + stderr_lines))
done
if [[ $stderr_total -gt 0 && $stderr_score -eq $stderr_total ]]; then
  code_quality=$((code_quality + 5))
elif [[ $stderr_total -eq 0 ]]; then
  code_quality=$((code_quality + 5))
fi

# 3b. All scripts have usage comments (5 points)
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
  code_quality=$((code_quality + 5))
fi

# 3c. All scripts document exit codes (5 points)
exitcode_count=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  if grep -q "Exit codes:" "$script" 2>/dev/null; then
    exitcode_count=$((exitcode_count + 1))
  fi
done
if [[ $script_count -gt 0 && $exitcode_count -eq $script_count ]]; then
  code_quality=$((code_quality + 5))
fi

# 3d. No hardcoded branch names (5 points)
hardcoded=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  # Check for hardcoded "main" or "master" as default (not in comments/echo)
  if grep -E '^\s*(BASE|base)="(main|master)"' "$script" 2>/dev/null | grep -v "^#" >/dev/null; then
    hardcoded=$((hardcoded + 1))
  fi
done
if [[ $hardcoded -eq 0 ]]; then
  code_quality=$((code_quality + 5))
fi

# 3e. Consistent error prefix format (5 points)
# All error messages should use "ERROR:" or "✗" consistently
inconsistent_errors=0
for script in "$SCRIPTS_DIR"/*.sh; do
  [[ "$(basename "$script")" == "autoresearch.sh" ]] && continue
  has_error_prefix=$(grep -c 'echo.*"ERROR:' "$script" 2>/dev/null || true)
  has_x_prefix=$(grep -c 'echo.*"✗' "$script" 2>/dev/null || true)
  # Having both styles in same script is inconsistent
  if [[ $has_error_prefix -gt 0 && $has_x_prefix -gt 0 ]]; then
    inconsistent_errors=$((inconsistent_errors + 1))
  fi
done
if [[ $inconsistent_errors -eq 0 ]]; then
  code_quality=$((code_quality + 5))
fi

score=$((score + code_quality))

# --- 4. SKILL.md Quality (max 25 points) ---
max_score=$((max_score + 25))
skillmd_quality=0

if [[ -f "$SKILL_MD" ]]; then
  # 4a. Has YAML frontmatter with name and description (5 points)
  if head -20 "$SKILL_MD" | grep -q "^---" && grep -q "^name:" "$SKILL_MD" && grep -q "^description:" "$SKILL_MD"; then
    skillmd_quality=$((skillmd_quality + 5))
  fi

  # 4b. Has required sections: Overview, When to Use, Workflow (5 points)
  sections=0
  grep -q "^## Overview" "$SKILL_MD" && sections=$((sections + 1))
  grep -q "^## When to Use" "$SKILL_MD" && sections=$((sections + 1))
  grep -q "^## Workflow" "$SKILL_MD" && sections=$((sections + 1))
  if [[ $sections -eq 3 ]]; then
    skillmd_quality=$((skillmd_quality + 5))
  elif [[ $sections -ge 2 ]]; then
    skillmd_quality=$((skillmd_quality + 3))
  fi

  # 4c. Has stop conditions (5 points)
  if grep -q "^## Stop Conditions" "$SKILL_MD" || grep -q "^## Stop" "$SKILL_MD"; then
    skillmd_quality=$((skillmd_quality + 5))
  fi

  # 4d. References actual script paths (5 points)
  script_refs=0
  grep -q "preflight-check" "$SKILL_MD" && script_refs=$((script_refs + 1))
  grep -q "wait-for-merge" "$SKILL_MD" && script_refs=$((script_refs + 1))
  if [[ $script_refs -ge 2 ]]; then
    skillmd_quality=$((skillmd_quality + 5))
  elif [[ $script_refs -ge 1 ]]; then
    skillmd_quality=$((skillmd_quality + 3))
  fi

  # 4e. Has error handling guidance (5 points)
  if grep -qi "error\|fail\|exit" "$SKILL_MD" && grep -qi "pr-pass\|fix\|resolve" "$SKILL_MD"; then
    skillmd_quality=$((skillmd_quality + 5))
  fi
fi

score=$((score + skillmd_quality))

# --- Output Metrics ---
echo "METRIC quality_score=$score"
echo "METRIC shellcheck_warnings=$shellcheck_warnings"
echo "METRIC test_pass_rate=${test_pass_rate:-0}"
echo "METRIC code_quality=$code_quality"
echo "METRIC skillmd_quality=$skillmd_quality"
echo "METRIC total_tests=${total_tests:-0}"
echo "METRIC max_score=$max_score"
