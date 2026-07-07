#!/usr/bin/env node

import { spawn } from "node:child_process";

const SERVER_INFO = { name: "jira-mcp-remote", version: "1.0.0" };
const DEFAULT_REMOTE_URL = "https://mcp.atlassian.com/v1/mcp/authv2";
const DEFAULT_REMOTE_PACKAGE = "mcp-remote@0.1.38";

const tools = [
  {
    name: "jira_auth_status",
    description: "Check whether the upstream Atlassian MCP connection is authenticated.",
    inputSchema: objectSchema({
      format: formatProperty()
    })
  },
  {
    name: "jira_list_sites",
    description: "List accessible Atlassian sites with Cloud IDs.",
    inputSchema: objectSchema({
      format: formatProperty()
    })
  },
  {
    name: "jira_list_projects",
    description: "List visible Jira projects in compact form.",
    inputSchema: objectSchema({
      cloudId: cloudIdProperty(),
      format: formatProperty(),
      limit: { type: "integer", minimum: 1, maximum: 50, default: 20, description: "Maximum projects to return." }
    })
  },
  {
    name: "jira_search_issues",
    description: "Search Jira issues with JQL and return a compact issue list.",
    inputSchema: objectSchema({
      cloudId: cloudIdProperty(),
      format: formatProperty(),
      jql: { type: "string", description: "Focused JQL query." },
      limit: { type: "integer", minimum: 1, maximum: 50, default: 10, description: "Maximum issues to return." }
    }, ["jql"])
  },
  {
    name: "jira_get_issue",
    description: "Fetch one Jira issue by key or ID.",
    inputSchema: objectSchema({
      cloudId: cloudIdProperty(),
      format: formatProperty(),
      issueIdOrKey: { type: "string", description: "Jira issue key or numeric ID." }
    }, ["issueIdOrKey"])
  },
  {
    name: "jira_create_issue",
    description: "Create one Jira issue after the user confirms the exact payload.",
    inputSchema: objectSchema({
      cloudId: cloudIdProperty(),
      projectKey: { type: "string", description: "Jira project key." },
      issueTypeName: { type: "string", description: "Issue type, for example Task, Story, Bug, or Epic." },
      summary: { type: "string", description: "Issue summary." },
      description: { type: "string", description: "Optional issue description in markdown." },
      format: formatProperty(),
      additional_fields: { type: "object", description: "Optional Jira fields to set on creation." },
      parent: { type: "string", description: "Optional parent issue key." },
      confirmed: { type: "boolean", description: "Must be true after showing the exact intended change to the user." }
    }, ["projectKey", "issueTypeName", "summary", "confirmed"])
  },
  {
    name: "jira_comment_issue",
    description: "Add one comment to a Jira issue after user confirmation.",
    inputSchema: objectSchema({
      cloudId: cloudIdProperty(),
      issueIdOrKey: { type: "string", description: "Jira issue key or numeric ID." },
      commentBody: { type: "string", description: "Comment body in markdown." },
      format: formatProperty(),
      confirmed: { type: "boolean", description: "Must be true after showing the exact comment to the user." }
    }, ["issueIdOrKey", "commentBody", "confirmed"])
  }
];

let inputBuffer = Buffer.alloc(0);

process.stdin.on("data", (chunk) => {
  inputBuffer = Buffer.concat([inputBuffer, chunk]);
  for (;;) {
    const message = readFrame();
    if (!message) return;
    void handleMessage(message);
  }
});

function objectSchema(properties, required = []) {
  return { type: "object", properties, required, additionalProperties: false };
}

function cloudIdProperty() {
  return {
    type: "string",
    description: "Atlassian Cloud ID or site URL. Defaults to JIRA_CLOUD_ID or ATLASSIAN_CLOUD_ID when omitted."
  };
}

function formatProperty() {
  return {
    type: "string",
    enum: ["text", "json"],
    default: "text",
    description: "Output format. Defaults to text for LLM-readable responses; use json for structured output."
  };
}

function readFrame() {
  const headerEnd = inputBuffer.indexOf("\r\n\r\n");
  if (headerEnd === -1) return null;

  const header = inputBuffer.subarray(0, headerEnd).toString("utf8");
  const match = header.match(/Content-Length: (\d+)/i);
  if (!match) {
    inputBuffer = inputBuffer.subarray(headerEnd + 4);
    return null;
  }

  const length = Number(match[1]);
  const bodyStart = headerEnd + 4;
  const bodyEnd = bodyStart + length;
  if (inputBuffer.length < bodyEnd) return null;

  const raw = inputBuffer.subarray(bodyStart, bodyEnd).toString("utf8");
  inputBuffer = inputBuffer.subarray(bodyEnd);
  return JSON.parse(raw);
}

async function handleMessage(message) {
  if (!("id" in message)) return;

  try {
    if (message.method === "initialize") {
      sendResult(message.id, {
        protocolVersion: message.params?.protocolVersion ?? "2025-06-18",
        capabilities: { tools: {} },
        serverInfo: SERVER_INFO
      });
      return;
    }

    if (message.method === "tools/list") {
      sendResult(message.id, { tools });
      return;
    }

    if (message.method === "tools/call") {
      const { name, arguments: args = {} } = message.params ?? {};
      const text = await callTool(name, args);
      sendResult(message.id, { content: [{ type: "text", text }] });
      return;
    }

    sendError(message.id, -32601, `Unknown method: ${message.method}`);
  } catch (error) {
    sendError(message.id, -32000, error instanceof Error ? error.message : String(error));
  }
}

async function callTool(name, args) {
  switch (name) {
    case "jira_auth_status":
      return authStatus(args);
    case "jira_list_sites":
      return callUpstreamCompact("getAccessibleAtlassianResources", {}, compactSitesResult, args, renderSitesText);
    case "jira_list_projects":
      return callUpstreamCompact("getVisibleJiraProjects", {
        cloudId: resolveCloudId(args),
        maxResults: clampLimit(args.limit, 20)
      }, (result) => compactProjectsResult(result, clampLimit(args.limit, 20)), args, renderProjectsText);
    case "jira_search_issues":
      return callUpstreamCompact("searchJiraIssuesUsingJql", {
        cloudId: resolveCloudId(args),
        jql: requireString(args.jql, "jql"),
        maxResults: clampLimit(args.limit, 10)
      }, compactIssuesResult, args, renderIssuesText);
    case "jira_get_issue":
      return callUpstreamCompact("getJiraIssue", {
        cloudId: resolveCloudId(args),
        issueIdOrKey: requireString(args.issueIdOrKey, "issueIdOrKey"),
        responseContentFormat: "markdown"
      }, compactIssueResult, args, renderIssueText);
    case "jira_create_issue":
      requireConfirmed(args);
      return callUpstreamCompact("createJiraIssue", {
        cloudId: resolveCloudId(args),
        projectKey: requireString(args.projectKey, "projectKey"),
        issueTypeName: requireString(args.issueTypeName, "issueTypeName"),
        summary: requireString(args.summary, "summary"),
        description: optionalString(args.description),
        additional_fields: args.additional_fields,
        parent: optionalString(args.parent),
        contentFormat: "markdown",
        responseContentFormat: "markdown"
      }, compactTextResult, args, renderResultText);
    case "jira_comment_issue":
      requireConfirmed(args);
      return callUpstreamCompact("addCommentToJiraIssue", {
        cloudId: resolveCloudId(args),
        issueIdOrKey: requireString(args.issueIdOrKey, "issueIdOrKey"),
        commentBody: requireString(args.commentBody, "commentBody"),
        contentFormat: "markdown",
        responseContentFormat: "markdown"
      }, compactTextResult, args, renderResultText);
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

async function authStatus(args) {
  try {
    const upstream = await withUpstream((client) => client.request("tools/list", {}));
    const upstreamToolCount = Array.isArray(upstream?.tools) ? upstream.tools.length : 0;
    return renderOutput({ status: "connected", upstreamToolCount }, args, renderAuthText);
  } catch (error) {
    return renderOutput({
      status: "not_connected",
      message: compactErrorMessage(error),
      hint: "Run this plugin once in an interactive environment so mcp-remote can complete Atlassian OAuth."
    }, args, renderAuthText);
  }
}

async function callUpstreamCompact(name, args, compact, toolArgs, renderText) {
  const result = await withUpstream((client) => client.request("tools/call", { name, arguments: pruneUndefined(args) }));
  return renderOutput(compact(result), toolArgs, renderText);
}

function resolveCloudId(args) {
  return optionalString(args.cloudId) || process.env.JIRA_CLOUD_ID || process.env.ATLASSIAN_CLOUD_ID || missingCloudId();
}

function missingCloudId() {
  throw new Error("Missing cloudId. Pass cloudId or set JIRA_CLOUD_ID/ATLASSIAN_CLOUD_ID.");
}

function requireString(value, field) {
  if (typeof value !== "string" || value.trim() === "") throw new Error(`Missing required string: ${field}`);
  return value;
}

function optionalString(value) {
  return typeof value === "string" && value.trim() !== "" ? value : undefined;
}

function clampLimit(value, fallback) {
  const number = Number(value ?? fallback);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(Math.max(Math.trunc(number), 1), 50);
}

function requireConfirmed(args) {
  if (args.confirmed !== true) {
    throw new Error("Write refused: show the exact intended Jira change to the user first, then retry with confirmed: true.");
  }
}

function pruneUndefined(value) {
  return Object.fromEntries(Object.entries(value).filter(([, entry]) => entry !== undefined));
}

function compactIssuesResult(result) {
  return {
    issues: extractItems(result).map(compactIssue).filter((issue) => Object.keys(issue).length > 0)
  };
}

function compactSitesResult(result) {
  return {
    sites: extractItems(result).map(compactSite).filter((site) => Object.keys(site).length > 0)
  };
}

function compactProjectsResult(result, limit) {
  return {
    projects: extractItems(result)
      .slice(0, limit)
      .map(compactProject)
      .filter((project) => Object.keys(project).length > 0)
  };
}

function compactIssueResult(result) {
  const items = extractItems(result);
  return { issue: compactIssue(items[0] ?? result) };
}

function compactTextResult(result) {
  return { result: extractText(result) || result };
}

function renderOutput(value, args, renderText) {
  if (args?.format === "json") return JSON.stringify(value, null, 2);
  return renderText(value);
}

function renderAuthText(value) {
  if (value.status === "connected") return `Jira MCP: connected (${value.upstreamToolCount} upstream tools)`;
  return `Jira MCP: not connected. ${value.message}\n${value.hint}`;
}

function renderSitesText(value) {
  if (!value.sites?.length) return "No accessible Atlassian sites found.";
  return ["Accessible Atlassian sites:", ...value.sites.map((site) => {
    const details = [`cloudId: ${site.id}`];
    if (site.scopes) details.push(`scopes: ${site.scopes}`);
    return `- ${site.name || site.url}: ${site.url}${details.length ? ` (${details.join("; ")})` : ""}`;
  })].join("\n");
}

function renderProjectsText(value) {
  if (!value.projects?.length) return "No Jira projects found.";
  return ["Jira projects:", ...value.projects.map((project) => {
    const suffix = [project.type, project.issueTypes ? `issue types: ${project.issueTypes}` : ""].filter(Boolean).join("; ");
    return `- ${project.key} - ${project.name}${suffix ? ` (${suffix})` : ""}`;
  })].join("\n");
}

function renderIssuesText(value) {
  if (!value.issues?.length) return "No Jira issues found.";
  return ["Jira issues:", ...value.issues.map((issue) => `- ${formatIssueLine(issue)}`)].join("\n");
}

function renderIssueText(value) {
  if (!value.issue || Object.keys(value.issue).length === 0) return "No Jira issue found.";
  return `Jira issue:\n- ${formatIssueLine(value.issue)}`;
}

function renderResultText(value) {
  return textOf(value.result) || "Jira operation completed.";
}

function formatIssueLine(issue) {
  const head = [
    issue.key,
    issue.type ? `[${issue.type}]` : "",
    issue.summary,
    issue.status ? `— ${issue.status}` : ""
  ].filter(Boolean).join(" ");
  const details = [
    issue.assignee ? `assignee: ${issue.assignee}` : "",
    issue.priority ? `priority: ${issue.priority}` : "",
    issue.url ? `url: ${issue.url}` : ""
  ].filter(Boolean);
  return details.length ? `${head}; ${details.join("; ")}` : head;
}

function extractItems(value) {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.issues)) return value.issues;
  if (Array.isArray(value?.workItems)) return value.workItems;
  if (Array.isArray(value?.values)) return value.values;
  if (Array.isArray(value?.content)) {
    const text = extractText(value);
    try {
      return extractItems(JSON.parse(text));
    } catch {
      return [{ text }];
    }
  }
  if (value && typeof value === "object") return [value];
  return [];
}

function compactIssue(issue) {
  const fields = issue?.fields ?? issue ?? {};
  return pruneEmpty({
    key: textOf(issue?.key ?? fields.key ?? fields.issueIdOrKey),
    type: textOf(fields.issuetype ?? fields.issueType ?? fields.issueTypeName ?? fields.type),
    summary: textOf(fields.summary),
    status: textOf(fields.status),
    assignee: textOf(fields.assignee),
    priority: textOf(fields.priority),
    url: textOf(issue?.url ?? fields.url),
    text: textOf(issue?.text ?? fields.text)
  });
}

function compactSite(site) {
  return pruneEmpty({
    id: textOf(site?.id),
    name: textOf(site?.name),
    url: textOf(site?.url),
    scopes: Array.isArray(site?.scopes) ? site.scopes.join(", ") : textOf(site?.scopes)
  });
}

function compactProject(project) {
  return pruneEmpty({
    id: textOf(project?.id),
    key: textOf(project?.key),
    name: textOf(project?.name),
    type: textOf(project?.projectTypeKey),
    issueTypes: Array.isArray(project?.issueTypes)
      ? project.issueTypes.map((issueType) => textOf(issueType?.name)).filter(Boolean).join(", ")
      : ""
  });
}

function pruneEmpty(value) {
  return Object.fromEntries(Object.entries(value).filter(([, entry]) => entry !== ""));
}

function textOf(value) {
  if (value == null) return "";
  if (typeof value === "string" || typeof value === "number" || typeof value === "boolean") return cleanText(value);
  if (typeof value.displayName === "string") return cleanText(value.displayName);
  if (typeof value.name === "string") return cleanText(value.name);
  if (typeof value.value === "string") return cleanText(value.value);
  if (typeof value.text === "string") return cleanText(value.text);
  return cleanText(JSON.stringify(value));
}

function cleanText(value) {
  return String(value).replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").trim();
}

function extractText(value) {
  if (typeof value === "string") return value.trim();
  if (Array.isArray(value?.content)) {
    return value.content
      .map((item) => item?.text ?? "")
      .filter(Boolean)
      .join("\n")
      .trim();
  }
  return "";
}

function compactErrorMessage(error) {
  const message = error instanceof Error ? error.message : String(error);
  if (/Please authorize this client|Authentication required|Waiting for authorization/i.test(message)) {
    return "Atlassian OAuth authorization is required.";
  }
  if (/Timed out waiting for upstream MCP response/i.test(message)) {
    return "Timed out waiting for upstream MCP response.";
  }
  return message.split(/\r?\n/)[0];
}

async function withUpstream(callback) {
  const client = startUpstreamClient();
  try {
    await client.initialize();
    return await callback(client);
  } finally {
    client.close();
  }
}

function startUpstreamClient() {
  const { command, args } = upstreamCommand();
  const child = spawn(command, args, { stdio: ["pipe", "pipe", "pipe"], env: process.env });
  let stdout = "";
  let stderr = "";
  let nextId = 1;

  child.stdout.setEncoding("utf8");
  child.stdout.on("data", (chunk) => { stdout += chunk; });
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => { stderr += chunk; });

  function write(message) {
    child.stdin.write(`${JSON.stringify(message)}\n`);
  }

  async function readResponse(id, timeoutMs = upstreamTimeoutMs()) {
    const started = Date.now();
    for (;;) {
      const message = takeMessage();
      if (message?.id === id) {
        if (message.error) throw new Error(message.error.message ?? JSON.stringify(message.error));
        return message.result;
      }
      if (Date.now() - started > timeoutMs) {
        throw new Error(`Timed out waiting for upstream MCP response. ${summarizeStderr(stderr)}`);
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
  }

  function takeMessage() {
    const index = stdout.indexOf("\n");
    if (index === -1) return null;
    const line = stdout.slice(0, index).replace(/\r$/, "");
    stdout = stdout.slice(index + 1);
    if (line.trim() === "") return null;
    return JSON.parse(line);
  }

  return {
    async initialize() {
      const id = nextId++;
      write({
        jsonrpc: "2.0",
        id,
        method: "initialize",
        params: {
          protocolVersion: "2025-06-18",
          capabilities: {},
          clientInfo: SERVER_INFO
        }
      });
      await readResponse(id);
      write({ jsonrpc: "2.0", method: "notifications/initialized", params: {} });
    },
    async request(method, params) {
      const id = nextId++;
      write({ jsonrpc: "2.0", id, method, params });
      return readResponse(id);
    },
    close() {
      child.kill();
    }
  };
}

function summarizeStderr(stderr) {
  const lines = stderr
    .split(/\r?\n/)
    .map((line) => line.replace(/^\[\d+\]\s*/, "").trim())
    .filter(Boolean);
  if (lines.some((line) => /Please authorize this client|Authentication required|Waiting for authorization/i.test(line))) {
    return "Atlassian OAuth authorization is required.";
  }
  const relevant = lines.filter((line) => !/^at\s/.test(line)).slice(-3);
  return relevant.length > 0 ? `upstream=${relevant.join(" | ")}` : "";
}

function upstreamCommand() {
  if (process.env.JIRA_MCP_REMOTE_COMMAND) {
    return {
      command: process.env.JIRA_MCP_REMOTE_COMMAND,
      args: process.env.JIRA_MCP_REMOTE_ARGS ? JSON.parse(process.env.JIRA_MCP_REMOTE_ARGS) : []
    };
  }

  return {
    command: "npx",
    args: ["-y", DEFAULT_REMOTE_PACKAGE, process.env.JIRA_MCP_REMOTE_URL || DEFAULT_REMOTE_URL]
  };
}

function upstreamTimeoutMs() {
  const value = Number(process.env.JIRA_MCP_UPSTREAM_TIMEOUT_MS ?? 120000);
  return Number.isFinite(value) && value > 0 ? value : 120000;
}

function sendResult(id, result) {
  send({ jsonrpc: "2.0", id, result });
}

function sendError(id, code, message) {
  send({ jsonrpc: "2.0", id, error: { code, message } });
}

function send(message) {
  const body = JSON.stringify(message);
  process.stdout.write(`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`);
}
