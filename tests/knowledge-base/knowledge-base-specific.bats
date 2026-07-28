#!/usr/bin/env bats

load ../helpers/bats_helper

setup() {
    ensure_jq
}

@test "knowledge-base exposes a local stdio MCP server" {
  local config="${PROJECT_ROOT}/plugins/knowledge-base/.mcp.json"
  local expected_args='["-lc","exec \"${KNOWLEDGE_BASE_BIN:-knowledge-base}\" mcp"]'

  [ "$(jq -r '.mcpServers["knowledge-base"].command' "$config")" = "sh" ]
  [ "$(jq -c '.mcpServers["knowledge-base"].args' "$config")" = "$expected_args" ]
  [ "$(jq -r '.mcpServers["knowledge-base"].cwd' "$config")" = "." ]
  [ "$(jq -r '.mcpServers["knowledge-base"].url // empty' "$config")" = "" ]
  jq -e '
    [.mcpServers["knowledge-base"].args[]]
    | join("\n")
    | test("npx|bunx|npm[[:space:]]+install|bun[[:space:]]+install"; "i")
    | not
  ' "$config" >/dev/null
}

@test "knowledge-base blocks qmd generation and reranking paths" {
  run grep -R -q '\.expandQuery(' "${PROJECT_ROOT}/plugins/knowledge-base/src"
  [ "$status" -eq 1 ]
  run grep -R -q 'rerank:[[:space:]]*true' "${PROJECT_ROOT}/plugins/knowledge-base/src"
  [ "$status" -eq 1 ]
  grep -R -q 'rerank:[[:space:]]*false' "${PROJECT_ROOT}/plugins/knowledge-base/src"
}
