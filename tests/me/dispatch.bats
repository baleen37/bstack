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

# --- resolve_binary tests ---

@test "dispatch: resolve_binary rejects semicolon in name" {
    run "$DISPATCH" --resolve-test "foo;bar"
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects ampersand in name" {
    run "$DISPATCH" --resolve-test "foo&bar"
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects pipe in name" {
    run "$DISPATCH" --resolve-test "foo|bar"
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects dollar sign in name" {
    run "$DISPATCH" --resolve-test 'foo$bar'
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects backtick in name" {
    run "$DISPATCH" --resolve-test 'foo`bar'
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects backslash in name" {
    run "$DISPATCH" --resolve-test 'foo\bar'
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects parentheses in name" {
    run "$DISPATCH" --resolve-test "foo(bar)"
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects angle brackets in name" {
    run "$DISPATCH" --resolve-test "foo<bar>"
    assert_failure
    assert_output_contains "forbidden characters"
}

@test "dispatch: resolve_binary rejects nonexistent binary" {
    run "$DISPATCH" --resolve-test "totally_nonexistent_binary_xyz_999"
    assert_failure
    assert_output_contains "Binary not found"
}

@test "dispatch: resolve_binary resolves valid binary to absolute path" {
    run "$DISPATCH" --resolve-test "bash"
    assert_success
    assert_output_matches "^/"
}

# --- build_command tests ---

@test "dispatch: build_command claude includes dangerously-skip-permissions" {
    run "$DISPATCH" --dry-run claude "test task"
    assert_success
    assert_output_contains "dangerously-skip-permissions"
}

@test "dispatch: build_command codex includes full-auto" {
    run "$DISPATCH" --dry-run codex "test task"
    assert_success
    assert_output_contains "full-auto"
}

@test "dispatch: build_command gemini includes yolo" {
    run "$DISPATCH" --dry-run gemini "test task"
    assert_success
    assert_output_contains "yolo"
}

@test "dispatch: build_command passes model flag" {
    run "$DISPATCH" --dry-run --model gpt-4.1 codex "test task"
    assert_success
    assert_output_contains "gpt-4.1"
}

@test "dispatch: fails when tmux not available" {
    PATH="/usr/bin:/bin" run "$DISPATCH" codex "test task"
    assert_failure
}

@test "dispatch: resolve_binary rejects binary in /tmp" {
    local tmp_dir="/tmp/dispatch-test-$$"
    mkdir -p "$tmp_dir"
    local fake_bin="${tmp_dir}/fakecmd"
    echo '#!/bin/sh' > "$fake_bin"
    chmod +x "$fake_bin"

    PATH="${tmp_dir}:${PATH}" run "$DISPATCH" --resolve-test "fakecmd"
    rm -rf "$tmp_dir"
    assert_failure
    assert_output_contains "untrusted path"
}
