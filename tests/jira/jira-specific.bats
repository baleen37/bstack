#!/usr/bin/env bats
# Jira (Atlassian) specific tests for consolidated structure
load ../helpers/bats_helper

@test "jira: .mcp.json exists and is valid" {
    [ -f "${PROJECT_ROOT}/.mcp.json" ]
    jq empty "${PROJECT_ROOT}/.mcp.json"
}

@test "jira: .mcp.json contains atlassian server config" {
    grep -q "atlassian" "${PROJECT_ROOT}/.mcp.json"
    grep -q "https://mcp.atlassian.com/v1/mcp" "${PROJECT_ROOT}/.mcp.json"
}

@test "jira: all 5 skills exist with SKILL.md" {
    [ -f "${PROJECT_ROOT}/skills/triage-issue/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/skills/capture-tasks-from-meeting-notes/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/skills/generate-status-report/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/skills/search-company-knowledge/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/skills/spec-to-backlog/SKILL.md" ]
}

@test "jira: skills have valid frontmatter" {
    local jira_skills=(
        "triage-issue"
        "capture-tasks-from-meeting-notes"
        "generate-status-report"
        "search-company-knowledge"
        "spec-to-backlog"
    )

    for skill_name in "${jira_skills[@]}"; do
        skill_file="${PROJECT_ROOT}/skills/${skill_name}/SKILL.md"
        [ -f "${skill_file}" ]
        grep -q "^---$" "${skill_file}"
        grep -q "^name:" "${skill_file}"
        grep -q "^description:" "${skill_file}"
    done
}
