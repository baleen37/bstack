#!/usr/bin/env bash
# Manual workflow test runner

WORKFLOW_DIR=".github/workflows"
RELEASE_WORKFLOW="${WORKFLOW_DIR}/release.yml"
CI_WORKFLOW="${WORKFLOW_DIR}/ci.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

echo "==================================="
echo "GitHub Actions Workflow Tests"
echo "==================================="
echo ""

# Test 1: Workflow directory exists
echo -n "Testing: Workflow directory exists ... "
if [ -d "$WORKFLOW_DIR" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 2: Release workflow file exists
echo -n "Testing: Release workflow file exists ... "
if [ -f "$RELEASE_WORKFLOW" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 3: Release workflow file is not empty
echo -n "Testing: Release workflow file is not empty ... "
if [ -s "$RELEASE_WORKFLOW" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 4: CI workflow file exists
echo -n "Testing: CI workflow file exists ... "
if [ -f "$CI_WORKFLOW" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 5: Release workflow has valid YAML syntax
echo -n "Testing: Release workflow has valid YAML syntax ... "
if yq eval '.' "$RELEASE_WORKFLOW" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 6: CI workflow has valid YAML syntax
echo -n "Testing: CI workflow has valid YAML syntax ... "
if yq eval '.' "$CI_WORKFLOW" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 7: Release workflow has push trigger
echo -n "Testing: Release workflow has push trigger ... "
if yq eval '.on.push' "$RELEASE_WORKFLOW" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 8: Release workflow has pull_request trigger
echo -n "Testing: Release workflow has pull_request trigger ... "
if yq eval '.on.pull_request' "$RELEASE_WORKFLOW" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 9: Release workflow has release job
echo -n "Testing: Release workflow has release job ... "
if yq eval '.jobs.release' "$RELEASE_WORKFLOW" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 10: Release workflow job has bot detection condition
echo "Testing: Release workflow job has bot detection condition"
if_condition=$(yq eval '.jobs.release.if' "$RELEASE_WORKFLOW" 2>/dev/null)
echo "  if_condition: $if_condition"
test_10_pass=true
if [ "$if_condition" = "null" ] || [ -z "$if_condition" ]; then
    echo "  Error: No if condition found"
    test_10_pass=false
elif ! echo "$if_condition" | grep -q 'github-actions\[bot\]'; then
    echo "  Error: if condition does not check for github-actions[bot]"
    test_10_pass=false
elif ! echo "$if_condition" | grep -q '!='; then
    echo "  Error: if condition does not use inequality operator"
    test_10_pass=false
fi

if [ "$test_10_pass" = "true" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 11: Release workflow has required permissions (contents: write)
echo -n "Testing: Release workflow has required permissions (contents: write) ... "
permissions=$(yq eval '.permissions.contents' "$RELEASE_WORKFLOW" 2>/dev/null)
if [ "$permissions" = "write" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 12: Release workflow runs tests before release
echo -n "Testing: Release workflow runs tests before release ... "
if grep -q 'Run tests' "$RELEASE_WORKFLOW" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Test 13: Release workflow uses chore(release): for bot commits
echo -n "Testing: Release workflow uses chore(release): for bot commits ... "
if grep -q 'chore(release):' "$RELEASE_WORKFLOW" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
echo "==================================="

if [ $FAIL -gt 0 ]; then
    exit 1
fi
