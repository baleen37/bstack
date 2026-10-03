#!/usr/bin/env bats

load ../helpers/bats_helper

DISPATCH="${PROJECT_ROOT}/scripts/dispatch.sh"

@test "dispatch: shows usage when missing args" {
    run "$DISPATCH"
    assert_failure
    assert_output_contains "Usage:"
}

@test "dispatch: rejects unknown tool" {
    run "$DISPATCH" foobar "some task"
    assert_failure
    assert_output_contains "Unknown tool"
}

@test "dispatch: rejects tool not in PATH" {
    PATH="/usr/bin:/bin" run "$DISPATCH" codex "some task"
    assert_failure
    assert_output_contains "not found"
}
