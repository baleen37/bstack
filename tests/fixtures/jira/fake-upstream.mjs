#!/usr/bin/env node

import { readFileSync } from "node:fs";

const fixturePath = process.argv[2];
const fixtures = JSON.parse(readFileSync(fixturePath, "utf8"));
let buffer = "";

process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buffer += chunk;
  for (;;) {
    const index = buffer.indexOf("\n");
    if (index === -1) return;
    const line = buffer.slice(0, index);
    buffer = buffer.slice(index + 1);
    if (line.trim() === "") continue;
    handleMessage(JSON.parse(line));
  }
});

function handleMessage(message) {
  if (message.method === "initialize") {
    send({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        protocolVersion: "2025-06-18",
        capabilities: { tools: {} },
        serverInfo: { name: "fake-upstream", version: "0" }
      }
    });
    return;
  }

  if (message.method === "tools/list") {
    send({ jsonrpc: "2.0", id: message.id, result: { tools: fixtures.tools } });
    return;
  }

  if (message.method === "tools/call") {
    const result = toolResult(message.params.name, message.params.arguments ?? {});
    send({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        content: [{ type: "text", text: JSON.stringify(result) }]
      }
    });
  }
}

function toolResult(name, args) {
  if (name === "addCommentToJiraIssue" && args.commentId) {
    if (args.commentId !== "10001") {
      return {
        text: `unexpected comment args: ${JSON.stringify(args)}`
      };
    }
    return fixtures.toolResults.updateCommentToJiraIssue;
  }
  if (name === "editJiraIssue" && args.issueIdOrKey === "AD-EMPTY" && args.fields?.description === null) {
    return fixtures.toolResults.nullDescriptionIgnoredIssue;
  }
  if (name === "editJiraIssue" && args.issueIdOrKey === "AD-EMPTY" && args.fields?.description === "") {
    return fixtures.toolResults.getEmptyDescriptionJiraIssue;
  }
  if (name === "getJiraIssue" && args.issueIdOrKey === "AD-2") {
    return fixtures.toolResults.getCreatedJiraIssue;
  }
  if (name === "getJiraIssue" && args.issueIdOrKey === "AD-EMPTY") {
    return fixtures.toolResults.getEmptyDescriptionJiraIssue;
  }
  if (name === "createJiraIssue") {
    if (args.additional_fields?.labels?.[0] !== "smoke" || args.additional_fields?.parent?.key !== "AD-0" || "parent" in args) {
      return {
        text: `unexpected create args: ${JSON.stringify(args)}`
      };
    }
  }
  if (name === "transitionJiraIssue" && (args.transition?.id !== "31" || "fields" in args || "update" in args)) {
    return {
      text: `unexpected transition args: ${JSON.stringify(args)}`
    };
  }
  return fixtures.toolResults[name];
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}
