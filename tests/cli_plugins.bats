#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "CLI plugins are listed and remain MCP-free" {
    local marketplace="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
    [ "$(jq -c '[.plugins[] | select(.name == "atlassian") | .name] | sort' "$marketplace")" = '["atlassian"]' ]

    for plugin in atlassian; do
        local manifest="${PROJECT_ROOT}/plugins/${plugin}/.claude-plugin/plugin.json"
        [ -f "$manifest" ]
        [ -d "${PROJECT_ROOT}/plugins/${plugin}/skills" ]
        [ ! -f "${PROJECT_ROOT}/plugins/${plugin}/.mcp.json" ]
        [ "$(jq -r '.mcpServers // empty' "$manifest")" = "" ]
    done
}
