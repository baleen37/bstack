#!/usr/bin/env bats
# Test: Claude Code's own validator accepts the marketplace and every plugin
# (manifest fields, skill/agent/command frontmatter).

load helpers/bats_helper

setup() {
    command -v claude >/dev/null 2>&1 || skip "claude CLI not installed"
}

@test "claude plugin validate accepts the marketplace" {
    run claude plugin validate --strict "${PROJECT_ROOT}"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "claude plugin validate accepts every plugin" {
    local plugin_dir failed=0
    for plugin_dir in "${PROJECT_ROOT}"/plugins/*/; do
        run claude plugin validate --strict "$plugin_dir"
        if [ "$status" -ne 0 ]; then
            echo "$output"
            failed=1
        fi
    done
    [ "$failed" -eq 0 ]
}
