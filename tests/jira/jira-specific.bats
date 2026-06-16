#!/usr/bin/env bats
# Jira (Atlassian) specific tests for consolidated structure
load ../helpers/bats_helper

@test "jira: all 6 skills exist with SKILL.md" {
    [ -f "${PROJECT_ROOT}/plugins/jira/skills/triage-issue/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/jira/skills/capture-tasks-from-meeting-notes/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/jira/skills/generate-status-report/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/jira/skills/search-company-knowledge/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/jira/skills/spec-to-backlog/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/jira/skills/daily-standup/SKILL.md" ]
}

@test "jira: plugin.json exists and is valid" {
    [ -f "${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json" ]
    jq empty "${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json"
}

@test "jira: plugin.json has required fields" {
    local f="${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json"
    jq -e '.name' "$f" >/dev/null
    jq -e '.description' "$f" >/dev/null
    jq -e '.version' "$f" >/dev/null
}
