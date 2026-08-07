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

@test "CLI skills advertise their real command surfaces" {
    grep -q 'twg' "${PROJECT_ROOT}/plugins/atlassian/skills/twg/SKILL.md"
    grep -q 'jira workitem search' "${PROJECT_ROOT}/plugins/atlassian/skills/twg-jira/SKILL.md"
    grep -q 'jira workitem get' "${PROJECT_ROOT}/plugins/atlassian/skills/twg-jira/SKILL.md"
}

@test "CLI skills document explicit safety boundaries" {
    local jira_skill="${PROJECT_ROOT}/plugins/atlassian/skills/twg-jira/SKILL.md"

    grep -q 'exact change, target, and expected impact' "$jira_skill"
    grep -q 'only after the user explicitly approves' "$jira_skill"
    grep -q 'whether or not --yes is present' "$jira_skill"
    grep -q 'Reads and searches remain allowed' "$jira_skill"
}
