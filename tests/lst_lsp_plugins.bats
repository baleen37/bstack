#!/usr/bin/env bats
# Test: lsp-* LSP plugin manifests and configs

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "lsp plugins: all 5 plugin manifests exist" {
    [ -f "${PROJECT_ROOT}/plugins/lsp-gopls/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lsp-typescript/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lsp-clangd/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lsp-lua/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lsp-pyright/.claude-plugin/plugin.json" ]
}

@test "lsp plugins: all 5 .lsp.json files exist and are valid JSON" {
    for p in lsp-gopls lsp-typescript lsp-clangd lsp-lua lsp-pyright; do
        local lsp_file="${PROJECT_ROOT}/plugins/${p}/.lsp.json"
        [ -f "$lsp_file" ]
        jq empty "$lsp_file"
    done
}

@test "lsp plugins: manifests point to .lsp.json" {
    for p in lsp-gopls lsp-typescript lsp-clangd lsp-lua lsp-pyright; do
        local manifest="${PROJECT_ROOT}/plugins/${p}/.claude-plugin/plugin.json"
        jq -e '.lspServers == "./.lsp.json"' "$manifest" >/dev/null
    done
}
