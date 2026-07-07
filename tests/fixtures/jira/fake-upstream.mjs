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
    send({
      jsonrpc: "2.0",
      id: message.id,
      result: {
        content: [{ type: "text", text: JSON.stringify(fixtures.toolResults[message.params.name]) }]
      }
    });
  }
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}
