#!/usr/bin/env bats
# Test: marketplace.json validation

load helpers/bats_helper
load helpers/marketplace_helper

MARKETPLACE_JSON="${PROJECT_ROOT}/.claude-plugin/marketplace.json"

setup() {
    ensure_jq
}

@test "public marketplace and project use the skills identity" {
    [ "$(json_get "$MARKETPLACE_JSON" "name")" = "skills" ]
    [ "$(jq -r '.name' "${PROJECT_ROOT}/package.json")" = "skills" ]
    grep -Fq 'claude plugin marketplace add https://github.com/baleen37/skills' "${PROJECT_ROOT}/README.md"
    grep -Fq 'claude plugin install core@skills' "${PROJECT_ROOT}/README.md"
}

@test "runtime workspaces use .skills and legacy state remains ignored" {
    grep -Fq '.skills/' "${PROJECT_ROOT}/.gitignore"
    grep -Fq '.bstack/' "${PROJECT_ROOT}/.gitignore"
    grep -Fq 'base="$root/.skills/sdd"' "${PROJECT_ROOT}/plugins/core/skills/subagent-driven-development/scripts/sdd-workspace"
}

@test "marketplace.json includes all plugins in plugins/ directory" {
    marketplace_all_plugins_listed "$MARKETPLACE_JSON"
}

@test "marketplace.json plugin sources point to existing directories" {
    marketplace_all_plugins_exist "$MARKETPLACE_JSON"
}
