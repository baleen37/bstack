#!/usr/bin/env bash
# run-all-tests.sh: Run all tests for consolidated plugin structure
#
# This script runs all tests in the project:
# 1. Root tests in tests/
# 2. Consolidated plugin structure tests
#
# Exit code: 0 if all tests pass, 1 if any test fails

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Track failures
FAILED_TESTS=()

# Function to run bats tests and track failures
run_tests() {
    local test_dir="$1"
    local label="$2"

    echo "========================================"
    echo "Running ${label}..."
    echo "========================================"

    if bats "${test_dir}"; then
        echo -e "${GREEN}✓ ${label} passed${NC}"
        return 0
    else
        echo -e "${RED}✗ ${label} failed${NC}"
        FAILED_TESTS+=("${label}")
        return 1
    fi
}

# Function to run consolidated structure tests
run_consolidated_tests() {
    echo "========================================"
    echo "Running consolidated plugin structure tests..."
    echo "========================================"

    # Run tests for each subdirectory in tests/
    local test_dirs=("integration" "skills" "performance" "me" "jira" "git-guard")
    
    for dir in "${test_dirs[@]}"; do
        if [ -d "${SCRIPT_DIR}/${dir}" ]; then
            run_tests "${SCRIPT_DIR}/${dir}" "${dir} tests"
        fi
    done
}

# Main execution
main() {
    echo -e "${YELLOW}Running all tests for consolidated plugin structure...${NC}"
    echo ""

    # 1. Run root tests
    run_tests "${SCRIPT_DIR}" "Root tests"

    # 2. Run consolidated structure tests
    run_consolidated_tests

    # 3. Report results
    echo ""
    echo "========================================"
    echo "Test Results Summary"
    echo "========================================"

    if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed:${NC}"
        for failed_test in "${FAILED_TESTS[@]}"; do
            echo "  - ${failed_test}"
        done
        exit 1
    fi
}

# Run main function
main "$@"
