#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "CLI plugins are listed and remain MCP-free" {
    local marketplace="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
    [ "$(jq -c '[.plugins[] | select(.name == "notion" or .name == "atlassian") | .name] | sort' "$marketplace")" = '["atlassian","notion"]' ]

    for plugin in notion atlassian; do
        local manifest="${PROJECT_ROOT}/plugins/${plugin}/.claude-plugin/plugin.json"
        [ -f "$manifest" ]
        [ -d "${PROJECT_ROOT}/plugins/${plugin}/skills" ]
        [ ! -f "${PROJECT_ROOT}/plugins/${plugin}/.mcp.json" ]
        [ "$(jq -r '.mcpServers // empty' "$manifest")" = "" ]
    done
}

@test "CLI skills advertise their real command surfaces" {
    grep -q 'ntn' "${PROJECT_ROOT}/plugins/notion/skills/notion/SKILL.md"
    grep -q 'twg' "${PROJECT_ROOT}/plugins/atlassian/skills/twg/SKILL.md"
    grep -q 'jira workitem search' "${PROJECT_ROOT}/plugins/atlassian/skills/twg-jira/SKILL.md"
    grep -q 'jira workitem get' "${PROJECT_ROOT}/plugins/atlassian/skills/twg-jira/SKILL.md"
}

@test "CLI skills document explicit safety boundaries" {
    local notion_skill="${PROJECT_ROOT}/plugins/notion/skills/notion/SKILL.md"
    local jira_skill="${PROJECT_ROOT}/plugins/atlassian/skills/twg-jira/SKILL.md"

    grep -q 'only when the user explicitly requests setup, auth, or repair' "$notion_skill"
    grep -q 'do not automatically install the CLI, start OAuth, or modify credentials' "$notion_skill"
    grep -q 'exact change, target, and expected impact' "$jira_skill"
    grep -q 'only after the user explicitly approves' "$jira_skill"
    grep -q 'whether or not --yes is present' "$jira_skill"
    grep -q 'Reads and searches remain allowed' "$jira_skill"
}
