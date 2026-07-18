#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

eligible_codex_plugins() {
    jq -r '.plugins[].source' "${PROJECT_ROOT}/.claude-plugin/marketplace.json" | \
    sed 's|^\./plugins/||' | \
    while IFS= read -r plugin; do
        [ -d "${PROJECT_ROOT}/plugins/${plugin}/skills" ] && echo "$plugin"
    done
}

@test "codex plugin manifests exist for skill plugins only" {
    local expected_plugins
    expected_plugins="$(eligible_codex_plugins)"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        assert_file_exists "${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
    done <<< "$expected_plugins"

    local actual_plugins
    actual_plugins="$(
        find "${PROJECT_ROOT}/plugins" -path '*/.codex-plugin/plugin.json' -print | \
        sed -E "s|^${PROJECT_ROOT}/plugins/([^/]+)/.codex-plugin/plugin.json$|\\1|" | \
        sort
    )"

    [ "$actual_plugins" = "$(printf '%s\n' "$expected_plugins" | sort)" ]
}

@test "codex plugin manifests are valid JSON" {
    local expected_plugins
    expected_plugins="$(eligible_codex_plugins)"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        validate_json "${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
    done <<< "$expected_plugins"
}

@test "codex plugin manifests point to shared skills directory" {
    local expected_plugins
    expected_plugins="$(eligible_codex_plugins)"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        local manifest="${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
        local skills_path
        skills_path=$(jq -r '.skills' "$manifest")
        [ "$skills_path" = "./skills/" ]
        [ -d "${PROJECT_ROOT}/plugins/${plugin}/skills" ]
    done <<< "$expected_plugins"
}

@test "codex and claude share the same skill sources" {
    local expected_plugins
    expected_plugins="$(eligible_codex_plugins)"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue

        local codex_manifest="${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"
        local skills_path
        skills_path=$(jq -r '.skills' "$codex_manifest")

        [ "$skills_path" = "./skills/" ]
        [ -d "${PROJECT_ROOT}/plugins/${plugin}/skills" ]
        [ ! -d "${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/skills" ]
        [ ! -d "${PROJECT_ROOT}/plugins/${plugin}/.claude-plugin/skills" ]
    done <<< "$expected_plugins"
}

@test "codex plugin manifests copy core metadata from claude manifests" {
    local expected_plugins
    expected_plugins="$(eligible_codex_plugins)"

    while IFS= read -r plugin; do
        [ -n "$plugin" ] || continue
        local claude_manifest="${PROJECT_ROOT}/plugins/${plugin}/.claude-plugin/plugin.json"
        local codex_manifest="${PROJECT_ROOT}/plugins/${plugin}/.codex-plugin/plugin.json"

        [ "$(jq -r '.name' "$claude_manifest")" = "$(jq -r '.name' "$codex_manifest")" ]
        [ "$(jq -r '.version' "$claude_manifest")" = "$(jq -r '.version' "$codex_manifest")" ]
        [ "$(jq -r '.description' "$claude_manifest")" = "$(jq -r '.description' "$codex_manifest")" ]
    done <<< "$expected_plugins"
}

@test "codex artifact drift check covers all generated plugin manifests" {
    local check_script="${PROJECT_ROOT}/scripts/check-codex-artifacts.sh"

    grep -q "'plugins/\\*/.codex-plugin/plugin.json'" "$check_script"
    grep -q "git ls-files --others --exclude-standard" "$check_script"
    ! grep -q "plugins/jira/.codex-plugin/plugin.json" "$check_script"
    ! grep -q "plugins/me/.codex-plugin/plugin.json" "$check_script"
    ! grep -q "plugins/ralph/.codex-plugin/plugin.json" "$check_script"
}

@test "marketplace sync workflow covers all generated codex plugin manifests" {
    local workflow="${PROJECT_ROOT}/.github/workflows/sync-marketplace.yml"

    grep -q "'plugins/\\*/.codex-plugin/plugin.json'" "$workflow"
    grep -q "git ls-files --others --exclude-standard" "$workflow"
    ! grep -q "plugins/jira/.codex-plugin/plugin.json" "$workflow"
    ! grep -q "plugins/me/.codex-plugin/plugin.json" "$workflow"
    ! grep -q "plugins/ralph/.codex-plugin/plugin.json" "$workflow"
}

@test "marketplace notification uses notify@v1 dispatch action" {
    local workflow="${PROJECT_ROOT}/.github/workflows/notify-marketplace.yml"

    grep -q "baleen37/baleen-marketplace/.github/actions/notify@v1" "$workflow"
    grep -q "source: bstack" "$workflow"
    grep -q "github.event.release.tag_name" "$workflow"
    grep -qF 'token: ${{ steps.app-token.outputs.token }}' "$workflow"
    grep -q "uses: actions/create-github-app-token@v1" "$workflow"
    grep -qF 'app-id: ${{ secrets.BALEEN_RELEASE_APP_ID }}' "$workflow"
    grep -qF 'private-key: ${{ secrets.BALEEN_RELEASE_APP_PRIVATE_KEY }}' "$workflow"
    ! grep -q "repository-dispatch@main" "$workflow"
    ! grep -q "dispatch-marketplace-update" "$workflow"
    ! grep -q "event-type: update_versions" "$workflow"
    ! grep -q "client-payload:" "$workflow"
    ! grep -q '"plugin":' "$workflow"
}
