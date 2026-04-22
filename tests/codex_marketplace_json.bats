#!/usr/bin/env bats

load helpers/bats_helper

MARKETPLACE_JSON="${PROJECT_ROOT}/.agents/plugins/marketplace.json"

setup() {
    ensure_jq
}

@test "codex marketplace exists and is valid JSON" {
    assert_file_exists "$MARKETPLACE_JSON"
    validate_json "$MARKETPLACE_JSON"
}

@test "codex marketplace includes only skill plugins in claude marketplace order" {
    local expected
    local actual

    expected="$(
        jq -r '.plugins[].source' "${PROJECT_ROOT}/.claude-plugin/marketplace.json" | \
        sed 's|^\./plugins/||' | \
        while IFS= read -r plugin; do
            [ -d "${PROJECT_ROOT}/plugins/${plugin}/skills" ] && echo "$plugin"
        done
    )"

    actual="$(
        jq -r '.plugins[].source.path' "$MARKETPLACE_JSON" | \
        sed 's|^\./plugins/||'
    )"

    [ "$actual" = "$expected" ]
}

@test "codex marketplace plugin entries use relative local paths and default policy" {
    local plugin_count
    plugin_count=$(jq -r '.plugins | length' "$MARKETPLACE_JSON")
    [ "$plugin_count" -eq 4 ]

    jq -e '
      .plugins
      | all(
          .source.source == "local" and
          (.source.path | startswith("./plugins/")) and
          .policy.installation == "AVAILABLE" and
          .policy.authentication == "ON_INSTALL" and
          .category == "Productivity"
        )
    ' "$MARKETPLACE_JSON"
}

@test "codex marketplace root name stays aligned with repository marketplace name" {
    local claude_name
    local codex_name

    claude_name=$(jq -r '.name' "${PROJECT_ROOT}/.claude-plugin/marketplace.json")
    codex_name=$(jq -r '.name' "$MARKETPLACE_JSON")

    [ "$codex_name" = "$claude_name" ]
    [ "$(jq -r '.interface.displayName' "$MARKETPLACE_JSON")" = "$claude_name" ]
}
