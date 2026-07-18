#!/usr/bin/env node

import { spawn } from "node:child_process";

const SERVER_INFO = { name: "jira-mcp-remote", version: "1.0.0" };
const DEFAULT_REMOTE_URL = "https://mcp.atlassian.com/v1/mcp/authv2";
const DEFAULT_REMOTE_PACKAGE = "mcp-remote@0.1.38";

const tools = [
  {
    name: "auth",
    description: "Auth.",
    inputSchema: objectSchema({})
  },
  {
    name: "sites",
    description: "Sites.",
    inputSchema: objectSchema({
      scopes: booleanProperty()
    })
  },
  {
    name: "projects",
    description: "Projects.",
    inputSchema: objectSchema({
      site: siteProperty(),
      types: booleanProperty(),
      limit: limitProperty(20)
    })
  },
  {
    name: "search",
    description: "Search JQL.",
    inputSchema: objectSchema({
      site: siteProperty(),
      jql: stringProperty(),
      limit: limitProperty(10)
    }, ["jql"])
  },
  {
    name: "issue",
    description: "Issue.",
    inputSchema: objectSchema({
      site: siteProperty(),
      desc: booleanProperty(),
      meta: booleanProperty(),
      key: stringProperty()
    }, ["key"])
  },
  {
    name: "create",
    description: "Create.",
    inputSchema: objectSchema({
      site: siteProperty(),
      project: stringProperty(),
      type: stringProperty(),
      summary: stringProperty(),
      description: stringProperty(),
      fields: objectProperty(),
      confirm: booleanProperty()
    }, ["project", "type", "summary", "confirm"])
  },
  {
    name: "comment",
    description: "Comment.",
    inputSchema: objectSchema({
      site: siteProperty(),
      key: stringProperty(),
      id: stringProperty(),
      body: stringProperty(),
      confirm: booleanProperty()
    }, ["key", "body", "confirm"])
  },
  {
    name: "update",
    description: "Update.",
    inputSchema: objectSchema({
      site: siteProperty(),
      key: stringProperty(),
      fields: objectProperty(),
      confirm: booleanProperty()
    }, ["key", "fields", "confirm"])
  },
  {
    name: "transitions",
    description: "Transitions.",
    inputSchema: objectSchema({
      site: siteProperty(),
      key: stringProperty(),
      to: booleanProperty()
    }, ["key"])
  },
  {
    name: "transition",
    description: "Transition.",
    inputSchema: objectSchema({
      site: siteProperty(),
      key: stringProperty(),
      id: stringProperty(),
      confirm: booleanProperty()
    }, ["key", "id", "confirm"])
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
  const schema = { type: "object" };
  if (Object.keys(properties).length > 0) schema.properties = properties;
  if (required.length > 0) schema.required = required;
  return schema;
}

function stringProperty() {
  return { type: "string" };
}

function objectProperty() {
  return { type: "object" };
}

function booleanProperty() {
  return { type: "boolean" };
}

function limitProperty() {
  return { type: "integer" };
}

function siteProperty() {
  return stringProperty();
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
    case "auth":
      return authStatus(args);
    case "sites":
      return callUpstreamCompact("getAccessibleAtlassianResources", {}, (result) => compactSitesResult(result, {
        scopes: args.scopes === true
      }), args, renderSitesText);
    case "projects":
      return callUpstreamCompact("getVisibleJiraProjects", {
        cloudId: resolveSite(args),
        maxResults: clampLimit(args.limit, 20)
      }, (result) => compactProjectsResult(result, clampLimit(args.limit, 20), {
        types: args.types === true
      }), args, renderProjectsText);
    case "search":
      return callUpstreamCompact("searchJiraIssuesUsingJql", {
        cloudId: resolveSite(args),
        jql: requireString(args.jql, "jql"),
        maxResults: clampLimit(args.limit, 10)
      }, compactIssuesResult, args, renderIssuesText);
    case "issue":
      return callUpstreamCompact("getJiraIssue", {
        cloudId: resolveSite(args),
        issueIdOrKey: requireString(args.key, "key"),
        responseContentFormat: "markdown"
      }, (result) => compactIssueResult(result, {
        description: args.desc === true,
        metadata: args.meta === true
      }), args, renderIssueText);
    case "create":
      return createIssue(args);
    case "comment":
      if (!isConfirmed(args)) return renderConfirmationRequired();
      requireConfirmed(args);
      return callUpstreamCompact("addCommentToJiraIssue", {
        cloudId: resolveSite(args),
        issueIdOrKey: requireString(args.key, "key"),
        commentId: optionalString(args.id),
        commentBody: requireString(args.body, "body"),
        contentFormat: "markdown",
        responseContentFormat: "markdown"
      }, compactCommentResult, args, renderCommentOrResultText);
    case "update":
      if (!isConfirmed(args)) return renderConfirmationRequired();
      requireConfirmed(args);
      const fields = requireObject(args.fields, "fields");
      return callUpstreamCompact("editJiraIssue", {
        cloudId: resolveSite(args),
        issueIdOrKey: requireString(args.key, "key"),
        fields: normalizeIssueFields(fields),
        contentFormat: "markdown",
        responseContentFormat: "markdown"
      }, (result) => compactIssueResult(result, { description: hasOwn(fields, "description") }), args, renderIssueText);
    case "transitions":
      return callUpstreamCompact("getTransitionsForJiraIssue", {
        cloudId: resolveSite(args),
        issueIdOrKey: requireString(args.key, "key")
      }, (result) => compactTransitionsResult(result, {
        toStatus: args.to === true
      }), args, renderTransitionsText);
    case "transition":
      if (!isConfirmed(args)) return renderConfirmationRequired();
      requireConfirmed(args);
      return callUpstreamCompact("transitionJiraIssue", {
        cloudId: resolveSite(args),
        issueIdOrKey: requireString(args.key, "key"),
        transition: { id: requireString(args.id, "id") }
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

async function createIssue(args) {
  if (!isConfirmed(args)) return renderConfirmationRequired();
  requireConfirmed(args);
  const cloudId = resolveSite(args);
  const createArgs = {
    cloudId,
    projectKey: requireString(args.project, "project"),
    issueTypeName: requireString(args.type, "type"),
    summary: requireString(args.summary, "summary"),
    description: optionalString(args.description),
    additional_fields: optionalObject(args.fields),
    contentFormat: "markdown",
    responseContentFormat: "markdown"
  };

  const compacted = await withUpstream(async (client) => {
    const created = await client.request("tools/call", { name: "createJiraIssue", arguments: pruneUndefined(createArgs) });
    const createdIssue = compactIssueOrTextResult(created);
    const issueKey = createdIssue.issue?.key;
    if (!issueKey || hasIssueDetails(createdIssue.issue)) return createdIssue;

    const fetched = await client.request("tools/call", {
      name: "getJiraIssue",
      arguments: {
        cloudId,
        issueIdOrKey: issueKey,
        responseContentFormat: "markdown"
      }
    });
    return compactIssueResult(fetched, { description: true });
  });

  return renderOutput(compacted, args, renderIssueOrResultText);
}

async function callUpstreamCompact(name, args, compact, toolArgs, renderText) {
  const result = await withUpstream((client) => client.request("tools/call", { name, arguments: pruneUndefined(args) }));
  return renderOutput(compact(result), toolArgs, renderText);
}

function resolveSite(args) {
  return optionalString(args.site) || process.env.JIRA_CLOUD_ID || process.env.ATLASSIAN_CLOUD_ID || missingSite();
}

function missingSite() {
  throw new Error("Missing site. Pass site or set JIRA_CLOUD_ID/ATLASSIAN_CLOUD_ID.");
}

function requireString(value, field) {
  if (typeof value !== "string" || value.trim() === "") throw new Error(`Missing required string: ${field}`);
  return value;
}

function optionalString(value) {
  return typeof value === "string" && value.trim() !== "" ? value : undefined;
}

function requireObject(value, field) {
  if (!isPlainObject(value)) throw new Error(`Missing required object: ${field}`);
  return value;
}

function optionalObject(value) {
  return isPlainObject(value) ? value : undefined;
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasIssueDetails(issue) {
  return Boolean(issue?.summary || issue?.description || issue?.status || issue?.type);
}

function normalizeIssueFields(fields) {
  if (fields.description !== null) return fields;
  return { ...fields, description: "" };
}

function hasOwn(value, field) {
  return Object.prototype.hasOwnProperty.call(value ?? {}, field);
}

function clampLimit(value, fallback) {
  const number = Number(value ?? fallback);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(Math.max(Math.trunc(number), 1), 50);
}

function requireConfirmed(args) {
  if (args.confirm !== true) {
    throw new Error("Write refused: show change; retry confirm=true.");
  }
}

function isConfirmed(args) {
  return args.confirm === true;
}

function renderConfirmationRequired() {
  return [
    "status: refused",
    "reason: confirm_required",
    "next: show change; retry confirm=true"
  ].join("\n");
}

function pruneUndefined(value) {
  return Object.fromEntries(Object.entries(value).filter(([, entry]) => entry !== undefined));
}

function compactIssuesResult(result) {
  return {
    issues: extractItems(result)
      .map((issue) => compactIssue(issue, { description: false }))
      .map(issueListItem)
      .filter((issue) => Object.keys(issue).length > 0)
  };
}

function compactSitesResult(result, options) {
  return {
    sites: extractItems(result)
      .map((site) => compactSite(site, options))
      .filter((site) => Object.keys(site).length > 0)
  };
}

function compactProjectsResult(result, limit, options) {
  return {
    projects: extractItems(result)
      .slice(0, limit)
      .map((project) => compactProject(project, options))
      .filter((project) => Object.keys(project).length > 0)
  };
}

function compactIssueResult(result, options) {
  const items = extractItems(result);
  return { issue: compactIssue(items[0] ?? result, options) };
}

function compactIssueOrTextResult(result) {
  const issue = compactIssue(extractItems(result)[0] ?? result);
  if (Object.keys(issue).length > 0) return { issue };
  return compactTextResult(result);
}

function compactTextResult(result) {
  const text = extractText(result);
  if (text) {
    try {
      return { result: JSON.parse(text) };
    } catch {
      return { result: text };
    }
  }
  return { result };
}

function compactCommentResult(result) {
  const value = compactTextResult(result).result;
  const comment = compactComment(value);
  if (Object.keys(comment).length > 0) return { comment };
  return { result: value };
}

function compactTransitionsResult(result, options) {
  return {
    transitions: extractItems(result)
      .map((transition) => compactTransition(transition, options))
      .filter((transition) => Object.keys(transition).length > 0)
  };
}

function renderOutput(value, args, renderText) {
  return renderText(value);
}

function renderAuthText(value) {
  if (value.status === "connected") return "auth: connected";
  return renderRecord("auth", value);
}

function renderSitesText(value) {
  return renderList("sites", value.sites);
}

function renderProjectsText(value) {
  return renderList("projects", value.projects);
}

function renderIssuesText(value) {
  return renderList("issues", value.issues?.map(issueListItem));
}

function renderIssueText(value) {
  if (!value.issue || Object.keys(value.issue).length === 0) return "issue: null";
  return renderRecord("issue", value.issue);
}

function renderIssueOrResultText(value) {
  if (value.issue) return renderIssueText(value);
  return renderResultText(value);
}

function renderCommentOrResultText(value) {
  if (value.comment) return renderRecord("comment", value.comment);
  return renderResultText(value);
}

function renderResultText(value) {
  return renderField("result", textOf(value.result) || "Jira operation completed.", "").join("\n");
}

function renderTransitionsText(value) {
  return renderList("transitions", value.transitions);
}

function issueListItem(issue) {
  return pruneEmpty({
    key: issue.key,
    type: issue.type,
    status: issue.status,
    summary: issue.summary
  });
}

function renderRecord(label, record) {
  return [`${label}:`, ...renderFields(record, "  ")].join("\n");
}

function renderList(label, items) {
  if (!items?.length) return `${label}: []`;
  return [`${label}:`, ...items.flatMap((item) => {
    const fields = renderFields(item, "  ");
    if (fields.length === 0) return ["- {}"];
    return [`- ${fields[0].trimStart()}`, ...fields.slice(1)];
  })].join("\n");
}

function renderFields(record, indent) {
  return Object.entries(record ?? {}).flatMap(([key, value]) => renderField(key, value, indent));
}

function renderField(key, value, indent) {
  const text = textOf(value);
  if (text === "") return [];
  if (!text.includes("\n")) return [`${indent}${key}: ${text}`];
  return [
    `${indent}${key}: |-`,
    ...text.split(/\r?\n/).map((line) => `${indent}  ${line}`)
  ];
}

function extractItems(value) {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.issues)) return value.issues;
  if (Array.isArray(value?.transitions)) return value.transitions;
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

function compactIssue(issue, options = {}) {
  const fields = issue?.fields ?? issue ?? {};
  const description = options.description !== false;
  const metadata = options.metadata === true;
  return pruneEmpty({
    key: textOf(issue?.key ?? fields.key ?? fields.issueIdOrKey),
    type: textOf(fields.issuetype ?? fields.issueType ?? fields.issueTypeName ?? fields.type),
    status: textOf(fields.status),
    summary: textOf(fields.summary),
    assignee: metadata ? textOf(fields.assignee) : "",
    priority: metadata ? textOf(fields.priority) : "",
    description: description ? descriptionText(fields.description ?? issue?.description) : "",
    url: textOf(issue?.url ?? fields.url),
    text: textOf(issue?.text ?? fields.text)
  });
}

function compactSite(site, options = {}) {
  const scopes = options.scopes === true;
  return pruneEmpty({
    id: textOf(site?.id),
    name: textOf(site?.name),
    url: textOf(site?.url),
    scopes: scopes && Array.isArray(site?.scopes) ? site.scopes.join(", ") : ""
  });
}

function compactProject(project, options = {}) {
  const types = options.types === true;
  return pruneEmpty({
    id: textOf(project?.id),
    key: textOf(project?.key),
    name: textOf(project?.name),
    type: textOf(project?.projectTypeKey),
    types: types && Array.isArray(project?.issueTypes)
      ? project.issueTypes.map((issueType) => textOf(issueType?.name)).filter(Boolean).join(", ")
      : ""
  });
}

function compactComment(comment) {
  if (!comment || typeof comment !== "object") return {};
  return pruneEmpty({
    id: textOf(comment.id),
    author: textOf(comment.author),
    created: textOf(comment.created),
    updated: textOf(comment.updated),
    body: textOf(comment.body)
  });
}

function compactTransition(transition, options = {}) {
  const toStatus = options.toStatus === true;
  return pruneEmpty({
    id: textOf(transition?.id),
    name: textOf(transition?.name),
    to: toStatus ? textOf(transition?.to) : ""
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

function descriptionText(value) {
  const text = textOf(value);
  if (isEmptyAdfDocument(text)) return "";
  return text;
}

function isEmptyAdfDocument(text) {
  try {
    const value = JSON.parse(text);
    return value?.type === "doc" && value?.version === 1 && Array.isArray(value.content) && value.content.length === 0;
  } catch {
    return false;
  }
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
