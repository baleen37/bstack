// Zero-dependency stdio MCP client. node built-ins only — no @modelcontextprotocol/sdk.
// A local stdio MCP server is just: spawn a process, exchange newline-delimited JSON-RPC.
// Copy into a scratch script, set CMD/ARGS, and chain callTool() — intermediate data stays
// in the script's variables, not in any model's context.
//
// Verified working against `npx -y @upstash/context7-mcp` and
// `npx -y @modelcontextprotocol/server-everything`.
//
// Handshake order is fixed: initialize -> notifications/initialized -> tools/call.
// Always tools/list first; never guess tool names or argument keys.

import { spawn } from "node:child_process";

export async function mcp(cmd, args = [], { protocolVersion = "2025-06-18" } = {}) {
  const proc = spawn(cmd, args, { stdio: ["pipe", "pipe", "ignore"] });
  let buf = "";
  let id = 1;
  const waiters = new Map();

  proc.stdout.on("data", (c) => {
    buf += c;
    let nl;
    while ((nl = buf.indexOf("\n")) !== -1) {
      const line = buf.slice(0, nl).trim();
      buf = buf.slice(nl + 1);
      if (!line) continue;
      let m;
      try { m = JSON.parse(line); } catch { continue; }
      if (waiters.has(m.id)) { waiters.get(m.id)(m); waiters.delete(m.id); }
    }
  });

  const req = (method, params) =>
    new Promise((res, rej) => {
      const i = id++;
      waiters.set(i, (m) => (m.error ? rej(new Error(m.error.message)) : res(m.result)));
      proc.stdin.write(JSON.stringify({ jsonrpc: "2.0", id: i, method, params }) + "\n");
    });

  await req("initialize", {
    protocolVersion,
    capabilities: {},
    clientInfo: { name: "scratch", version: "0" },
  });
  proc.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");

  return {
    listTools: async () => (await req("tools/list", {})).tools,
    call: async (name, args = {}) => {
      const r = await req("tools/call", { name, arguments: args });
      return r.content?.map((c) => c.text ?? JSON.stringify(c)).join("\n") ?? JSON.stringify(r);
    },
    close: () => proc.kill(),
  };
}

// Example: resolve -> query, chained; only the final string is surfaced.
//   const c = await mcp("npx", ["-y", "@upstash/context7-mcp"]);
//   console.log(await c.listTools());            // inspect names first, don't guess
//   const lib = await c.call("resolve-library-id", { libraryName: "Next.js", query: "router" });
//   const docs = await c.call("query-docs", { libraryId: pick(lib), query: "app router" });
//   c.close();
