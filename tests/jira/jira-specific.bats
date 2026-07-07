#!/usr/bin/env bats
# Jira (Atlassian) specific tests for consolidated structure
load ../helpers/bats_helper

@test "jira: plugin.json exists and is valid" {
    [ -f "${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json" ]
    jq empty "${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json"
}

@test "jira: plugin.json has required fields" {
    local f="${PROJECT_ROOT}/plugins/jira/.claude-plugin/plugin.json"
    jq -e '.name' "$f" >/dev/null
    jq -e '.description' "$f" >/dev/null
    jq -e '.version' "$f" >/dev/null
    [ "$(jq -r '.skills' "$f")" = "./skills/" ]
    [ "$(jq -r '.mcpServers' "$f")" = "./.mcp.json" ]
}

@test "jira: uses local Atlassian MCP facade" {
    local f="${PROJECT_ROOT}/plugins/jira/.mcp.json"
    jq empty "$f"
    [ "$(jq -r '.mcpServers.jira.command' "$f")" = "sh" ]
    [ "$(jq -r '.mcpServers.jira.args | join(" ")' "$f")" = '-lc exec "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$PWD}}/bin/jira-mcp-remote.mjs"' ]
    [ "$(jq -r '.mcpServers.jira.cwd' "$f")" = "." ]
    [ "$(jq -r '.mcpServers.atlassian // empty' "$f")" = "" ]
    [ -x "${PROJECT_ROOT}/plugins/jira/bin/jira-mcp-remote.mjs" ]
}

@test "jira: local MCP facade exposes compact tools" {
    node - "${PROJECT_ROOT}/plugins/jira/bin/jira-mcp-remote.mjs" <<'NODE'
const { spawn } = require("node:child_process");
const assert = require("node:assert/strict");

const serverPath = process.argv[2];
const child = spawn(serverPath, [], { stdio: ["pipe", "pipe", "pipe"] });
let stdout = Buffer.alloc(0);
let stderr = "";

child.stdout.on("data", (chunk) => {
  stdout = Buffer.concat([stdout, chunk]);
});
child.stderr.on("data", (chunk) => {
  stderr += chunk.toString("utf8");
});

function send(message) {
  const body = JSON.stringify(message);
  child.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
}

function readMessage() {
  return new Promise((resolve, reject) => {
    const deadline = setTimeout(() => {
      reject(new Error(`Timed out waiting for MCP response. stderr=${stderr}`));
    }, 2000);

    const poll = () => {
      const headerEnd = stdout.indexOf("\r\n\r\n");
      if (headerEnd === -1) {
        setTimeout(poll, 10);
        return;
      }

      const header = stdout.subarray(0, headerEnd).toString("utf8");
      const match = header.match(/Content-Length: (\d+)/i);
      assert.ok(match, `Missing Content-Length in ${header}`);
      const length = Number(match[1]);
      const bodyStart = headerEnd + 4;
      const bodyEnd = bodyStart + length;
      if (stdout.length < bodyEnd) {
        setTimeout(poll, 10);
        return;
      }

      const body = stdout.subarray(bodyStart, bodyEnd).toString("utf8");
      stdout = stdout.subarray(bodyEnd);
      clearTimeout(deadline);
      resolve(JSON.parse(body));
    };

    poll();
  });
}

(async () => {
  send({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "0.0.0" } } });
  const init = await readMessage();
  assert.equal(init.result.serverInfo.name, "jira-mcp-remote");

  send({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
  send({ jsonrpc: "2.0", id: 2, method: "tools/list", params: {} });
  const listed = await readMessage();
  const names = listed.result.tools.map((tool) => tool.name).sort();
  assert.deepEqual(names, ["jira_auth_status", "jira_comment_issue", "jira_create_issue", "jira_get_issue", "jira_list_projects", "jira_list_sites", "jira_search_issues"]);

  const search = listed.result.tools.find((tool) => tool.name === "jira_search_issues");
  assert.deepEqual(Object.keys(search.inputSchema.properties).sort(), ["cloudId", "format", "jql", "limit"]);
  assert.equal(search.inputSchema.additionalProperties, false);

  const projects = listed.result.tools.find((tool) => tool.name === "jira_list_projects");
  assert.deepEqual(Object.keys(projects.inputSchema.properties).sort(), ["cloudId", "format", "limit"]);
  assert.equal(projects.inputSchema.additionalProperties, false);

  const auth = listed.result.tools.find((tool) => tool.name === "jira_auth_status");
  assert.deepEqual(Object.keys(auth.inputSchema.properties).sort(), ["format"]);
  assert.equal(auth.inputSchema.properties.format.default, "text");

  send({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "jira_create_issue", arguments: { cloudId: "site", projectKey: "KEY", issueTypeName: "Task", summary: "No write", confirmed: false } } });
  const refused = await readMessage();
  assert.match(refused.error.message, /confirmed: true/);

  child.kill();
})().catch((error) => {
  child.kill();
  console.error(error);
  process.exit(1);
});
NODE
}

@test "jira: local MCP facade speaks newline JSON to upstream mcp-remote" {
    node - "${PROJECT_ROOT}/plugins/jira/bin/jira-mcp-remote.mjs" "${PROJECT_ROOT}/tests/fixtures/jira/fake-upstream.mjs" "${PROJECT_ROOT}/tests/fixtures/jira/fake-upstream.json" <<'NODE'
const { spawn } = require("node:child_process");
const assert = require("node:assert/strict");

const [serverPath, upstreamPath, fixturePath] = process.argv.slice(2);
const child = spawn(serverPath, [], {
  stdio: ["pipe", "pipe", "pipe"],
  env: {
    ...process.env,
    JIRA_MCP_REMOTE_COMMAND: process.execPath,
    JIRA_MCP_REMOTE_ARGS: JSON.stringify([upstreamPath, fixturePath]),
    JIRA_MCP_UPSTREAM_TIMEOUT_MS: "2000"
  }
});
let stdout = Buffer.alloc(0);
let stderr = "";

child.stdout.on("data", (chunk) => {
  stdout = Buffer.concat([stdout, chunk]);
});
child.stderr.on("data", (chunk) => {
  stderr += chunk.toString("utf8");
});

function send(message) {
  const body = JSON.stringify(message);
  child.stdin.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
}

function readMessage() {
  return new Promise((resolve, reject) => {
    const deadline = setTimeout(() => {
      reject(new Error(`Timed out waiting for MCP response. stderr=${stderr}`));
    }, 3000);

    const poll = () => {
      const headerEnd = stdout.indexOf("\r\n\r\n");
      if (headerEnd === -1) {
        setTimeout(poll, 10);
        return;
      }

      const header = stdout.subarray(0, headerEnd).toString("utf8");
      const match = header.match(/Content-Length: (\d+)/i);
      assert.ok(match, `Missing Content-Length in ${header}`);
      const length = Number(match[1]);
      const bodyStart = headerEnd + 4;
      const bodyEnd = bodyStart + length;
      if (stdout.length < bodyEnd) {
        setTimeout(poll, 10);
        return;
      }

      const body = stdout.subarray(bodyStart, bodyEnd).toString("utf8");
      stdout = stdout.subarray(bodyEnd);
      clearTimeout(deadline);
      resolve(JSON.parse(body));
    };

    poll();
  });
}

(async () => {
  send({ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "test", version: "0.0.0" } } });
  await readMessage();

  send({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
  send({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "jira_auth_status", arguments: { format: "json" } } });
  const status = await readMessage();
  const body = JSON.parse(status.result.content[0].text);

  assert.equal(body.status, "connected");
  assert.equal(body.upstreamToolCount, 2);
  assert.equal(body.upstreamTools, undefined);

  send({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "jira_search_issues", arguments: { cloudId: "site", jql: "project = AD", limit: 1 } } });
  const textSearch = await readMessage();
  assert.equal(textSearch.result.content[0].text, "Jira issues:\n- AD-1 [Task] Fix login — In Progress; assignee: Jane; priority: High");

  send({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "jira_search_issues", arguments: { cloudId: "site", jql: "project = AD", limit: 1, format: "json" } } });
  const jsonSearch = await readMessage();
  assert.equal(JSON.parse(jsonSearch.result.content[0].text).issues[0].key, "AD-1");

  child.kill();
})().catch((error) => {
  child.kill();
  console.error(error);
  process.exit(1);
});
NODE
}
