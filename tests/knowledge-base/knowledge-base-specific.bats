#!/usr/bin/env bats

load ../helpers/bats_helper

setup() {
    ensure_jq
}

run_mcp_stdio_client() {
  local package_dir="$1"
  local cli="$2"
  local inject_banner="$3"
  local result

  pushd "$package_dir" >/dev/null
  run env \
    KNOWLEDGE_BASE_CONFIG_DIR="${TEST_TEMP_DIR}/config" \
    KNOWLEDGE_BASE_DATA_DIR="${TEST_TEMP_DIR}/data" \
    KNOWLEDGE_BASE_CACHE_DIR="${TEST_TEMP_DIR}/cache" \
    KNOWLEDGE_BASE_STDIO_BANNER="$inject_banner" \
    node --input-type=module --eval '
      import { Client } from "@modelcontextprotocol/sdk/client/index.js";
      import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

      const timeout = 2_000;
      const expectBanner = process.env.KNOWLEDGE_BASE_STDIO_BANNER === "1";
      const cli = process.argv[1];
      const bannerWrapper = `
        import { spawn } from "node:child_process";
        process.stdout.write("non-JSON application banner\\n");
        const child = spawn(process.execPath, [${JSON.stringify(cli)}, "mcp"], { stdio: ["pipe", "pipe", "pipe"] });
        process.stdin.pipe(child.stdin);
        process.stdin.once("end", () => process.stderr.write("stdio cleanup sentinel\\n"));
        child.stdout.pipe(process.stdout);
        child.stderr.pipe(process.stderr);
        child.once("close", (code) => { process.exitCode = code ?? 1; });
      `;
      const transport = new StdioClientTransport({
        command: process.execPath,
        args: expectBanner ? ["--input-type=module", "--eval", bannerWrapper] : [cli, "mcp"],
        env: process.env,
        stderr: "pipe",
      });
      const client = new Client({ name: "knowledge-base-stdio-smoke", version: "1.0.0" });
      const stderr = transport.stderr;
      if (stderr === null) throw new Error("MCP child stderr was not captured");
      let stderrOutput = "";
      let stderrEnded = false;
      const stderrDone = new Promise((resolve, reject) => {
        stderr.setEncoding("utf8");
        stderr.on("data", (chunk) => { stderrOutput += chunk; });
        stderr.once("end", () => {
          stderrEnded = true;
          resolve();
        });
        stderr.once("error", reject);
      });
      let rejectProtocol;
      let protocolError;
      const protocolFailure = new Promise((_, reject) => { rejectProtocol = reject; });
      transport.onerror = (error) => {
        protocolError = error;
        rejectProtocol(error);
      };
      const withDeadline = (operation, name, protocol) => {
        let timer;
        const contenders = [
          operation,
          new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(`${name} timed out`)), timeout); }),
        ];
        if (protocol) contenders.push(protocolFailure);
        return Promise.race(contenders).finally(() => clearTimeout(timer));
      };
      let failure;
      let cleanupFailure;
      try {
        await withDeadline(client.connect(transport), "MCP initialize", true);
        const { tools } = await withDeadline(client.listTools(), "MCP tools/list", true);
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
          await withDeadline(client.close(), "MCP close", false);
        } catch (error) {
          cleanupFailure = error;
        }
        try {
          await withDeadline(stderrDone, "MCP stderr drain", false);
        } catch (error) {
          if (cleanupFailure === undefined) cleanupFailure = error;
        }
      }
      if (failure === undefined && cleanupFailure !== undefined) failure = cleanupFailure;
      if (expectBanner) {
        if (protocolError === undefined || failure === undefined) {
          throw new Error("non-JSON stdout banner did not fail the MCP protocol");
        }
        if (cleanupFailure !== undefined) throw cleanupFailure;
        if (!stderrEnded) throw new Error("MCP stderr did not end");
        if (stderrOutput !== "stdio cleanup sentinel\n") {
          throw new Error(`stderr was not fully drained: ${stderrOutput}`);
        }
      } else {
        if (failure !== undefined) throw failure;
        if (stderrOutput !== "") throw new Error(`MCP child wrote stderr: ${stderrOutput}`);
      }
    ' "$cli"
  result=$status
  popd >/dev/null
  return "$result"
}

@test "knowledge-base exposes a local stdio MCP server" {
  local config="${PROJECT_ROOT}/plugins/knowledge-base/.mcp.json"
  local expected_args='["-lc","exec node \"${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$PWD}}/dist/cli.js\" mcp"]'

  # Codex sets PLUGIN_ROOT, Claude Code sets CLAUDE_PLUGIN_ROOT, and neither
  # expands the other's variable. Only a shell can evaluate the fallback chain,
  # so this stays shell form like plugins/jira/.mcp.json.
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

@test "knowledge-base ships the built CLI it points at" {
  local plugin_dir="${PROJECT_ROOT}/plugins/knowledge-base"

  # The marketplace copies the plugin directory verbatim, so dist/ must be
  # tracked rather than gitignored.
  run git -C "$PROJECT_ROOT" check-ignore -q plugins/knowledge-base/dist/cli.js
  [ "$status" -ne 0 ]
  run git -C "$PROJECT_ROOT" ls-files --error-unmatch plugins/knowledge-base/dist/cli.js
  [ "$status" -eq 0 ]
  [ -f "${plugin_dir}/dist/cli.js" ]
}

@test "knowledge-base installs its native dependencies from a session hook" {
  local hooks="${PROJECT_ROOT}/plugins/knowledge-base/hooks/hooks.json"
  local script="${PROJECT_ROOT}/plugins/knowledge-base/hooks/install-deps.sh"
  local expected='bash "${PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/hooks/install-deps.sh"'

  [ "$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$hooks")" = "$expected" ]
  [ -x "$script" ]

  # npm 12 skips these builds unless the generated manifest allows them, which
  # leaves the dependency tree looking complete but every search broken.
  grep -q '"better-sqlite3": true' "$script"
  grep -q '"node-llama-cpp": true' "$script"
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

  run_mcp_stdio_client "$package_dir" "$cli" 0
  [ "$?" -eq 0 ]
}

@test "knowledge-base rejects a stdout banner and still drains child stderr" {
  local package_dir="${PROJECT_ROOT}/plugins/knowledge-base"
  local cli="${package_dir}/dist/cli.js"

  run bun run --cwd "$package_dir" build
  [ "$status" -eq 0 ]
  run_mcp_stdio_client "$package_dir" "$cli" 1
  [ "$?" -eq 0 ]
}
