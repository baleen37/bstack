#!/usr/bin/env bats
# Git Guard specific tests for consolidated structure
# Basic validation is handled in tests/ directory

load ../helpers/bats_helper

@test "git-guard: commit-guard.sh hook script exists" {
    [ -f "${PROJECT_ROOT}/hooks/commit-guard.sh" ]
}

@test "git-guard: pre-commit-guard.sh hook script exists" {
    [ -f "${PROJECT_ROOT}/hooks/pre-commit-guard.sh" ]
}

@test "git-guard: hook scripts use proper error handling" {
    grep -q "set -euo pipefail" "${PROJECT_ROOT}/hooks/commit-guard.sh"
    grep -q "set -euo pipefail" "${PROJECT_ROOT}/hooks/pre-commit-guard.sh"
}

@test "git-guard: hooks.json references hook scripts" {
    local hooks_json="${PROJECT_ROOT}/hooks/hooks.json"
    validate_json "$hooks_json"
    # Verify hook scripts are referenced
    grep -q "commit-guard.sh" "$hooks_json" || grep -q "pre-commit-guard.sh" "$hooks_json"
}

# commit-guard.sh functional tests
@test "git-guard: commit-guard blocks --no-verify" {
    run bash -c "set -o pipefail; echo '{\"command\":\"git commit --no-verify -m \\\"test\\\"\"}' | '${PROJECT_ROOT}/hooks/commit-guard.sh'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not allowed"* ]]
}

@test "git-guard: commit-guard blocks --no-verify with amend" {
    run bash -c "set -o pipefail; echo '{\"command\":\"git commit --amend --no-verify\"}' | '${PROJECT_ROOT}/hooks/commit-guard.sh'"
    [ "$status" -eq 2 ]
}

@test "git-guard: commit-guard blocks HUSKY=0" {
    run bash -c "set -o pipefail; echo '{\"command\":\"HUSKY=0 git commit -m \\\"test\\\"\"}' | '${PROJECT_ROOT}/hooks/commit-guard.sh'"
    [ "$status" -eq 2 ]
}

@test "git-guard: commit-guard blocks SKIP_HOOKS" {
    run bash -c "set -o pipefail; echo '{\"command\":\"SKIP_HOOKS=1 git commit -m \\\"test\\\"\"}' | '${PROJECT_ROOT}/hooks/commit-guard.sh'"
    [ "$status" -eq 2 ]
}

@test "git-guard: commit-guard allows normal git commit" {
    run bash -c "set -o pipefail; echo '{\"command\":\"git commit -m \\\"normal commit\\\"\"}' | '${PROJECT_ROOT}/hooks/commit-guard.sh'"
    [ "$status" -eq 0 ]
}

@test "git-guard: commit-guard blocks skip-hooks pattern" {
    run bash -c "set -o pipefail; echo '{\"command\":\"git commit --skip-hooks -m \\\"test\\\"\"}' | '${PROJECT_ROOT}/hooks/commit-guard.sh'"
    [ "$status" -eq 2 ]
}

@test "git-guard: commit-guard blocks --no-commit-hook" {
    run bash -c "set -o pipefail; echo '{\"command\":\"git commit --no-commit-hook -m \\\"test\\\"\"}' | '${PROJECT_ROOT}/hooks/commit-guard.sh'"
    [ "$status" -eq 2 ]
}

# Additional security: dangerous git commands that can bypass hooks
@test "git-guard: commit-guard blocks git update-ref" {
    local json_input='{"command":"git update-ref HEAD <old-sha> <new-sha>"}'
    run bash -c "echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not allowed"* ]]
}

@test "git-guard: commit-guard blocks git filter-branch" {
    local json_input='{"command":"git filter-branch --force --index-filter ..."}'
    run bash -c "echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not allowed"* ]]
}

@test "git-guard: commit-guard blocks hooksPath modification" {
    local json_input='{"command":"git config core.hooksPath /dev/null"}'
    run bash -c "echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"not allowed"* ]]
}

@test "git-guard: commit-guard allows git config for non-hooks" {
    local json_input='{"command":"git config user.name \"Test User\""}'
    run bash -c "echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 0 ]
}

# Co-Authored-By blocking tests
@test "git-guard: commit-guard blocks Co-Authored-By in commit message" {
    local json_input='{"command":"git commit -m \"test message\\n\\n-Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>\""}'
    run bash -c "set -o pipefail; echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Co-Authored-By"*"not allowed"* ]]
}

@test "git-guard: commit-guard blocks Co-Authored-By variant (without dash)" {
    local json_input='{"command":"git commit -m \"test\\n\\nCo-Authored-By: test\""}'
    run bash -c "set -o pipefail; echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 2 ]
}

@test "git-guard: commit-guard allows commit without Co-Authored-By" {
    local json_input='{"command":"git commit -m \"normal commit message\""}'
    run bash -c "set -o pipefail; echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 0 ]
}

@test "git-guard: commit-guard blocks Co-Authored-By with multiple -m flags" {
    local json_input='{"command":"git commit -m \"first line\" -m \"second line\" -m \"Co-Authored-By: test\""}'
    run bash -c "set -o pipefail; echo '$json_input' | ${PROJECT_ROOT}/hooks/commit-guard.sh"
    [ "$status" -eq 2 ]
}
