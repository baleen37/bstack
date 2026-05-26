#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "codex plugin manifests exist for skill plugins only" {
    local expected_plugins=("jira" "me" "ralph")

    for plugin in "${expected_plugins[@]}"; do
        assert_file_exists "${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
    done

    [ ! -e "${PROJECT_ROOT}/plugins/core/.codex-plugin/plugin.json" ]
}

@test "codex plugin manifests are valid JSON" {
    local expected_plugins=("jira" "me" "ralph")

    for plugin in "${expected_plugins[@]}"; do
        validate_json "${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
    done
}

@test "codex plugin manifests point to shared skills directory" {
    local expected_plugins=("jira" "me" "ralph")

    for plugin in "${expected_plugins[@]}"; do
        local manifest="${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
        local skills_path
        skills_path=$(jq -r '.skills' "$manifest")
        [ "$skills_path" = "./skills/" ]
        [ -d "${PROJECT_ROOT}/plugins/${plugin}/skills" ]
    done
}

@test "codex plugin manifests copy core metadata from claude manifests" {
    local expected_plugins=("jira" "me" "ralph")

    for plugin in "${expected_plugins[@]}"; do
        local claude_manifest="${PROJECT_ROOT}/plugins/${plugin}/.claude-plugin/plugin.json"
        local codex_manifest="${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"

        [ "$(jq -r '.name' "$claude_manifest")" = "$(jq -r '.name' "$codex_manifest")" ]
        [ "$(jq -r '.version' "$claude_manifest")" = "$(jq -r '.version' "$codex_manifest")" ]
        [ "$(jq -r '.description' "$claude_manifest")" = "$(jq -r '.description' "$codex_manifest")" ]
    done
}
