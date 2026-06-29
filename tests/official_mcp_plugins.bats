#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "official mcp plugins expose claude and codex manifests" {
    local plugin
    for plugin in slack notion jira; do
        assert_file_exists "${PROJECT_ROOT}/plugins/${plugin}/.claude-plugin/plugin.json"
        assert_file_exists "${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
        assert_file_exists "${PROJECT_ROOT}/plugins/${plugin}/.mcp.json"

        [ "$(jq -r '.mcpServers' "${PROJECT_ROOT}/plugins/${plugin}/.claude-plugin/plugin.json")" = "./.mcp.json" ]
        [ "$(jq -r '.mcpServers' "${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json")" = "./.mcp.json" ]
    done
}

@test "official mcp plugins use expected server endpoints" {
    [ "$(jq -r '.mcpServers.slack.url' "${PROJECT_ROOT}/plugins/slack/.mcp.json")" = "https://mcp.slack.com/mcp" ]
    [ "$(jq -r '.mcpServers.notion.url' "${PROJECT_ROOT}/plugins/notion/.mcp.json")" = "https://mcp.notion.com/mcp" ]
    [ "$(jq -r '.mcpServers.atlassian.url' "${PROJECT_ROOT}/plugins/jira/.mcp.json")" = "https://mcp.atlassian.com/v1/mcp/authv2" ]
}

@test "datadog stays cli based without an mcp server" {
    assert_file_exists "${PROJECT_ROOT}/plugins/datadog/.claude-plugin/plugin.json"
    assert_file_exists "${PROJECT_ROOT}/plugins/datadog/.codex-plugin/plugin.json"
    [ ! -f "${PROJECT_ROOT}/plugins/datadog/.mcp.json" ]
    [ "$(jq -r '.mcpServers // empty' "${PROJECT_ROOT}/plugins/datadog/.claude-plugin/plugin.json")" = "" ]
    [ "$(jq -r '.mcpServers // empty' "${PROJECT_ROOT}/plugins/datadog/.codex-plugin/plugin.json")" = "" ]
}
