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
  assert.ok(Buffer.byteLength(JSON.stringify(listed.result)) <= 2050);
  const names = listed.result.tools.map((tool) => tool.name).sort();
  assert.deepEqual(names, ["auth", "comment", "create", "issue", "projects", "search", "sites", "transition", "transitions", "update"]);
  assert.equal(names.some((name) => name.includes("delete")), false);

  assert.deepEqual(Object.fromEntries(listed.result.tools.map((tool) => [tool.name, tool.description])), {
    auth: "Auth.",
    comment: "Comment.",
    create: "Create.",
    issue: "Issue.",
    projects: "Projects.",
    search: "Search JQL.",
    sites: "Sites.",
    transition: "Transition.",
    transitions: "Transitions.",
    update: "Update."
  });

  const search = listed.result.tools.find((tool) => tool.name === "search");
  assert.deepEqual(Object.keys(search.inputSchema.properties).sort(), ["jql", "limit", "site"]);
  assert.deepEqual(search.inputSchema.properties.limit, { type: "integer" });
  assert.equal("additionalProperties" in search.inputSchema, false);

  const getIssue = listed.result.tools.find((tool) => tool.name === "issue");
  assert.deepEqual(Object.keys(getIssue.inputSchema.properties).sort(), ["desc", "key", "meta", "site"]);
  assert.equal(getIssue.inputSchema.properties.desc.type, "boolean");
  assert.equal(getIssue.inputSchema.properties.meta.type, "boolean");
  assert.equal("additionalProperties" in getIssue.inputSchema, false);

  const create = listed.result.tools.find((tool) => tool.name === "create");
  assert.deepEqual(Object.keys(create.inputSchema.properties).sort(), ["confirm", "description", "fields", "project", "site", "summary", "type"]);
  assert.equal(create.inputSchema.properties.fields.type, "object");
  assert.deepEqual(create.inputSchema.required, ["project", "type", "summary", "confirm"]);

  const projects = listed.result.tools.find((tool) => tool.name === "projects");
  assert.deepEqual(Object.keys(projects.inputSchema.properties).sort(), ["limit", "site", "types"]);
  assert.equal(projects.inputSchema.properties.types.type, "boolean");
  assert.deepEqual(projects.inputSchema.properties.limit, { type: "integer" });
  assert.equal("additionalProperties" in projects.inputSchema, false);
  assert.equal("required" in projects.inputSchema, false);

  const auth = listed.result.tools.find((tool) => tool.name === "auth");
  assert.equal("properties" in auth.inputSchema, false);
  assert.equal("required" in auth.inputSchema, false);

  const sitesTool = listed.result.tools.find((tool) => tool.name === "sites");
  assert.deepEqual(Object.keys(sitesTool.inputSchema.properties).sort(), ["scopes"]);
  assert.equal(sitesTool.inputSchema.properties.scopes.type, "boolean");
  assert.equal("additionalProperties" in sitesTool.inputSchema, false);
  assert.equal("required" in sitesTool.inputSchema, false);

  const transitionsTool = listed.result.tools.find((tool) => tool.name === "transitions");
  assert.deepEqual(Object.keys(transitionsTool.inputSchema.properties).sort(), ["key", "site", "to"]);
  assert.equal(transitionsTool.inputSchema.properties.to.type, "boolean");
  assert.equal("additionalProperties" in transitionsTool.inputSchema, false);

  const update = listed.result.tools.find((tool) => tool.name === "update");
  assert.deepEqual(Object.keys(update.inputSchema.properties).sort(), ["confirm", "fields", "key", "site"]);
  assert.deepEqual(update.inputSchema.required, ["key", "fields", "confirm"]);

  const comment = listed.result.tools.find((tool) => tool.name === "comment");
  assert.deepEqual(Object.keys(comment.inputSchema.properties).sort(), ["body", "confirm", "id", "key", "site"]);
  assert.deepEqual(comment.inputSchema.required, ["key", "body", "confirm"]);

  const transition = listed.result.tools.find((tool) => tool.name === "transition");
  assert.deepEqual(Object.keys(transition.inputSchema.properties).sort(), ["confirm", "id", "key", "site"]);
  assert.deepEqual(transition.inputSchema.required, ["key", "id", "confirm"]);

  send({ jsonrpc: "2.0", id: 3, method: "tools/call", params: { name: "create", arguments: { site: "site", project: "KEY", type: "Task", summary: "No write", confirm: false } } });
  const refused = await readMessage();
  assert.equal(refused.result.content[0].text, "status: refused\nreason: confirm_required\nnext: show change; retry confirm=true");

  send({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "update", arguments: { site: "site", key: "KEY-1", fields: { summary: "No write" }, confirm: false } } });
  const updateRefused = await readMessage();
  assert.equal(updateRefused.result.content[0].text, "status: refused\nreason: confirm_required\nnext: show change; retry confirm=true");

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
  send({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "auth", arguments: {} } });
  const status = await readMessage();
  assert.equal(status.result.content[0].text, "auth: connected");

  send({ jsonrpc: "2.0", id: 4, method: "tools/call", params: { name: "sites", arguments: {} } });
  const sites = await readMessage();
  assert.equal(sites.result.content[0].text, "sites:\n- id: site\n  name: Example\n  url: https://example.atlassian.net");

  send({ jsonrpc: "2.0", id: 5, method: "tools/call", params: { name: "sites", arguments: { scopes: true } } });
  const sitesWithScopes = await readMessage();
  assert.equal(sitesWithScopes.result.content[0].text, "sites:\n- id: site\n  name: Example\n  url: https://example.atlassian.net\n  scopes: read:jira-work, write:jira-work");

  send({ jsonrpc: "2.0", id: 6, method: "tools/call", params: { name: "projects", arguments: { site: "site", limit: 1 } } });
  const projects = await readMessage();
  assert.equal(projects.result.content[0].text, "projects:\n- id: 10000\n  key: AD\n  name: Ads\n  type: software");

  send({ jsonrpc: "2.0", id: 7, method: "tools/call", params: { name: "projects", arguments: { site: "site", limit: 1, types: true } } });
  const projectsWithTypes = await readMessage();
  assert.equal(projectsWithTypes.result.content[0].text, "projects:\n- id: 10000\n  key: AD\n  name: Ads\n  type: software\n  types: Task, Story");

  send({ jsonrpc: "2.0", id: 8, method: "tools/call", params: { name: "issue", arguments: { site: "site", key: "AD-1" } } });
  const issue = await readMessage();
  assert.equal(issue.result.content[0].text, "issue:\n  key: AD-1\n  type: Task\n  status: In Progress\n  summary: Fix login");

  send({ jsonrpc: "2.0", id: 9, method: "tools/call", params: { name: "issue", arguments: { site: "site", key: "AD-1", meta: true } } });
  const issueWithMetadata = await readMessage();
  assert.equal(issueWithMetadata.result.content[0].text, "issue:\n  key: AD-1\n  type: Task\n  status: In Progress\n  summary: Fix login\n  assignee: Jane\n  priority: High");

  send({ jsonrpc: "2.0", id: 10, method: "tools/call", params: { name: "issue", arguments: { site: "site", key: "AD-1", desc: true } } });
  const issueWithDescription = await readMessage();
  assert.equal(issueWithDescription.result.content[0].text, "issue:\n  key: AD-1\n  type: Task\n  status: In Progress\n  summary: Fix login\n  description: |-\n    Existing description\n    with two lines");

  send({ jsonrpc: "2.0", id: 11, method: "tools/call", params: { name: "issue", arguments: { site: "site", key: "AD-EMPTY", desc: true } } });
  const emptyIssue = await readMessage();
  assert.equal(emptyIssue.result.content[0].text, "issue:\n  key: AD-EMPTY\n  type: Task\n  status: Backlog\n  summary: Empty description");

  send({ jsonrpc: "2.0", id: 12, method: "tools/call", params: { name: "search", arguments: { site: "site", jql: "project = AD", limit: 1 } } });
  const textSearch = await readMessage();
  assert.equal(textSearch.result.content[0].text, "issues:\n- key: AD-1\n  type: Task\n  status: In Progress\n  summary: Fix login");

  send({ jsonrpc: "2.0", id: 14, method: "tools/call", params: { name: "create", arguments: { site: "site", project: "AD", type: "Task", summary: "Created from smoke", description: "Created description\nwith two lines", fields: { labels: ["smoke"], parent: { key: "AD-0" } }, confirm: true } } });
  const createIssue = await readMessage();
  assert.equal(createIssue.result.content[0].text, "issue:\n  key: AD-2\n  type: Task\n  status: To Do\n  summary: Created from smoke\n  description: |-\n    Created description\n    with two lines");

  send({ jsonrpc: "2.0", id: 15, method: "tools/call", params: { name: "comment", arguments: { site: "site", key: "AD-1", body: "Smoke comment", confirm: true } } });
  const commentIssue = await readMessage();
  assert.equal(commentIssue.result.content[0].text, "comment:\n  id: 10000\n  author: Jane\n  created: 2026-07-07T10:00:00.000+0900\n  updated: 2026-07-07T10:00:00.000+0900\n  body: Smoke comment");

  send({ jsonrpc: "2.0", id: 16, method: "tools/call", params: { name: "update", arguments: { site: "site", key: "AD-1", fields: { summary: "Fix login safely", description: "Updated description\nwith two lines" }, confirm: true } } });
  const updateIssue = await readMessage();
  assert.equal(updateIssue.result.content[0].text, "issue:\n  key: AD-1\n  type: Task\n  status: In Progress\n  summary: Fix login safely\n  description: |-\n    Updated description\n    with two lines");

  send({ jsonrpc: "2.0", id: 17, method: "tools/call", params: { name: "comment", arguments: { site: "site", key: "AD-1", id: "10001", body: "Updated comment", confirm: true } } });
  const updateComment = await readMessage();
  assert.equal(updateComment.result.content[0].text, "comment:\n  id: 10001\n  author: Jane\n  created: 2026-07-07T10:00:00.000+0900\n  updated: 2026-07-07T10:05:00.000+0900\n  body: Updated comment");

  send({ jsonrpc: "2.0", id: 18, method: "tools/call", params: { name: "update", arguments: { site: "site", key: "AD-EMPTY", fields: { description: null }, confirm: true } } });
  const clearDescription = await readMessage();
  assert.equal(clearDescription.result.content[0].text, "issue:\n  key: AD-EMPTY\n  type: Task\n  status: Backlog\n  summary: Empty description");

  send({ jsonrpc: "2.0", id: 19, method: "tools/call", params: { name: "transitions", arguments: { site: "site", key: "AD-1" } } });
  const transitions = await readMessage();
  assert.equal(transitions.result.content[0].text, "transitions:\n- id: 31\n  name: Done");

  send({ jsonrpc: "2.0", id: 20, method: "tools/call", params: { name: "transitions", arguments: { site: "site", key: "AD-1", to: true } } });
  const transitionsWithToStatus = await readMessage();
  assert.equal(transitionsWithToStatus.result.content[0].text, "transitions:\n- id: 31\n  name: Done\n  to: Done");

  send({ jsonrpc: "2.0", id: 21, method: "tools/call", params: { name: "transition", arguments: { site: "site", key: "AD-1", id: "31", confirm: true } } });
  const transitionIssue = await readMessage();
  assert.equal(transitionIssue.result.content[0].text, "result: Transitioned AD-1 to Done");

  child.kill();
})().catch((error) => {
  child.kill();
  console.error(error);
  process.exit(1);
});
NODE
}
