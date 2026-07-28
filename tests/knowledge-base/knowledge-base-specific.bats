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

@test "knowledge-base built CLI serves MCP only over stdio" {
  local package_dir="${PROJECT_ROOT}/plugins/knowledge-base"
  local cli="${package_dir}/dist/cli.js"

  run bun run --cwd "$package_dir" build
  [ "$status" -eq 0 ]
  [ -f "$cli" ]

  pushd "$package_dir" >/dev/null
  run env \
    KNOWLEDGE_BASE_CONFIG_DIR="${TEST_TEMP_DIR}/config" \
    KNOWLEDGE_BASE_DATA_DIR="${TEST_TEMP_DIR}/data" \
    KNOWLEDGE_BASE_CACHE_DIR="${TEST_TEMP_DIR}/cache" \
    node --input-type=module --eval '
      import { Client } from "@modelcontextprotocol/sdk/client/index.js";
      import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

      const timeout = 2_000;
      const transport = new StdioClientTransport({
        command: process.execPath,
        args: [process.argv[1], "mcp"],
        env: process.env,
        stderr: "pipe",
      });
      const client = new Client({ name: "knowledge-base-stdio-smoke", version: "1.0.0" });
      const stderr = transport.stderr;
      if (stderr === null) throw new Error("MCP child stderr was not captured");
      let stderrOutput = "";
      const stderrDone = new Promise((resolve, reject) => {
        stderr.setEncoding("utf8");
        stderr.on("data", (chunk) => { stderrOutput += chunk; });
        stderr.once("end", resolve);
        stderr.once("error", reject);
      });
      let rejectProtocol;
      const protocolFailure = new Promise((_, reject) => { rejectProtocol = reject; });
      transport.onerror = (error) => rejectProtocol(error);
      const within = (operation, name) => {
        let timer;
        return Promise.race([
          operation,
          protocolFailure,
          new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(`${name} timed out`)), timeout); }),
        ]).finally(() => clearTimeout(timer));
      };
      let failure;
      try {
        await within(client.connect(transport), "MCP initialize");
        const { tools } = await within(client.listTools(), "MCP tools/list");
        const names = tools.map((tool) => tool.name).sort();
        if (JSON.stringify(names) !== JSON.stringify(["get", "search", "status"])) {
          throw new Error(`unexpected MCP tools: ${JSON.stringify(names)}`);
        }
        if (client.getServerVersion()?.name !== "knowledge-base") {
          throw new Error("MCP initialization did not report knowledge-base");
        }
      } catch (error) {
        failure = error;
      } finally {
        try {
          await within(client.close(), "MCP close");
          await within(stderrDone, "MCP stderr drain");
        } catch (error) {
          if (failure === undefined) failure = error;
        }
      }
      if (failure !== undefined) throw failure;
      if (stderrOutput !== "") throw new Error(`MCP child wrote stderr: ${stderrOutput}`);
    ' "$cli"
  popd >/dev/null
  [ "$status" -eq 0 ]
}
