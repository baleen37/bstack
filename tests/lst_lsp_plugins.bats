#!/usr/bin/env bats
# Test: lsp-* LSP plugin manifests and configs

load helpers/bats_helper

setup() {
    ensure_jq
    LSP_PLUGINS=()
    while IFS= read -r dir; do
        LSP_PLUGINS+=("$dir")
    done < <(find "${PROJECT_ROOT}/plugins" -maxdepth 1 -type d -name "lsp-*" | sort)
}

@test "lsp plugins: at least one lsp-* plugin exists" {
    [ "${#LSP_PLUGINS[@]}" -gt 0 ]
}

@test "lsp plugins: all plugin manifests exist" {
    for plugin_dir in "${LSP_PLUGINS[@]}"; do
        assert_file_exists "${plugin_dir}/.claude-plugin/plugin.json"
    done
}

@test "lsp plugins: all .lsp.json files exist and are valid JSON" {
    for plugin_dir in "${LSP_PLUGINS[@]}"; do
        assert_file_exists "${plugin_dir}/.lsp.json"
        validate_json "${plugin_dir}/.lsp.json"
    done
}

@test "lsp plugins: manifests point to .lsp.json" {
    for plugin_dir in "${LSP_PLUGINS[@]}"; do
        local manifest="${plugin_dir}/.claude-plugin/plugin.json"
        jq -e '.lspServers == "./.lsp.json"' "$manifest" >/dev/null
    done
}

@test "lsp plugins: plugin names match directory names" {
    for plugin_dir in "${LSP_PLUGINS[@]}"; do
        local dir_name manifest name
        dir_name=$(basename "$plugin_dir")
        manifest="${plugin_dir}/.claude-plugin/plugin.json"
        name=$(jq -r '.name' "$manifest")
        assert_eq "$name" "$dir_name"
    done
}

@test "lsp plugins: each .lsp.json has command and extensionToLanguage" {
    for plugin_dir in "${LSP_PLUGINS[@]}"; do
        local lsp_file="${plugin_dir}/.lsp.json"
        # 각 언어 키에 대해 command와 extensionToLanguage 필드 확인
        jq -e 'to_entries[] | .value | has("command") and has("extensionToLanguage")' "$lsp_file" >/dev/null
    done
}
