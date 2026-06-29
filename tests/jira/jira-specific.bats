#!/usr/bin/env bats
# Jira (Atlassian) specific tests for consolidated structure
load ../helpers/bats_helper

@test "jira: plugin.json exists and is valid" {
    [ -f "${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json" ]
    jq empty "${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json"
}

@test "jira: plugin.json has required fields" {
    local f="${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json"
    jq -e '.name' "$f" >/dev/null
    jq -e '.description' "$f" >/dev/null
    jq -e '.version' "$f" >/dev/null
    [ "$(jq -r '.skills' "$f")" = "./skills/" ]
    [ "$(jq -r '.mcpServers' "$f")" = "./.mcp.json" ]
}

@test "jira: uses official Atlassian MCP endpoint" {
    local f="${PROJECT_ROOT}/plugins/jira/.mcp.json"
    jq empty "$f"
    [ "$(jq -r '.mcpServers.atlassian.url' "$f")" = "https://mcp.atlassian.com/v1/mcp/authv2" ]
}
