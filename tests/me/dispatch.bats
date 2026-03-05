#!/usr/bin/env bats
# Tests for dispatch.sh argument parsing

load ../helpers/bats_helper

DISPATCH="${PROJECT_ROOT}/scripts/dispatch.sh"

@test "dispatch: shows usage when no args" {
    run "$DISPATCH"
    assert_failure
    assert_output_contains "Usage:"
}

@test "dispatch: shows usage for unknown tool" {
    run "$DISPATCH" unknown-tool "some task"
    assert_failure
    assert_output_contains "Unknown tool"
}

@test "dispatch: rejects empty task" {
    run "$DISPATCH" claude ""
    assert_failure
    assert_output_contains "Task must not be empty"
}

@test "dispatch: parses --model option" {
    run "$DISPATCH" --dry-run --model sonnet claude "do something"
    assert_success
    assert_output_contains "MODEL=sonnet"
}

@test "dispatch: parses --timeout option" {
    run "$DISPATCH" --dry-run --timeout 300 claude "do something"
    assert_success
    assert_output_contains "TIMEOUT=300"
}

@test "dispatch: parses --cwd option" {
    run "$DISPATCH" --dry-run --cwd /tmp claude "do something"
    assert_success
    assert_output_contains "CWD=/tmp"
}
