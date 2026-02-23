#!/usr/bin/env bats
# Test: lst-* LSP plugin manifests and configs

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "lst plugins: all 6 plugin manifests exist" {
    [ -f "${PROJECT_ROOT}/plugins/lst-gopls/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lst-typescript/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lst-csharp/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lst-clangd/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lst-lua/.claude-plugin/plugin.json" ]
    [ -f "${PROJECT_ROOT}/plugins/lst-pyright/.claude-plugin/plugin.json" ]
}

@test "lst plugins: all 6 .lsp.json files exist and are valid JSON" {
    for p in lst-gopls lst-typescript lst-csharp lst-clangd lst-lua lst-pyright; do
        local lsp_file="${PROJECT_ROOT}/plugins/${p}/.lsp.json"
        [ -f "$lsp_file" ]
        jq empty "$lsp_file"
    done
}

@test "lst plugins: manifests point to .lsp.json" {
    for p in lst-gopls lst-typescript lst-csharp lst-clangd lst-lua lst-pyright; do
        local manifest="${PROJECT_ROOT}/plugins/${p}/.claude-plugin/plugin.json"
        jq -e '.lspServers == "./.lsp.json"' "$manifest" >/dev/null
    done
}
