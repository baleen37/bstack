#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "datadog stays cli based without an mcp server" {
    assert_file_exists "${PROJECT_ROOT}/plugins/datadog/.claude-plugin/plugin.json"
    assert_file_exists "${PROJECT_ROOT}/plugins/datadog/.codex-plugin/plugin.json"
    [ ! -f "${PROJECT_ROOT}/plugins/datadog/.mcp.json" ]
    [ "$(jq -r '.mcpServers // empty' "${PROJECT_ROOT}/plugins/datadog/.claude-plugin/plugin.json")" = "" ]
    [ "$(jq -r '.mcpServers // empty' "${PROJECT_ROOT}/plugins/datadog/.codex-plugin/plugin.json")" = "" ]
}

@test "marketplace contains the supported bstack plugins" {
    local manifest="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
    [ "$(jq -c '[.plugins[].name] | sort' "$manifest")" = '["atlassian","autoresearch","datadog","me","notion"]' ]
}
