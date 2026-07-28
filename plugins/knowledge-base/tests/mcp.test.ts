import { execFile as execFileCallback, spawn } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { beforeAll, afterEach, describe, expect, it, vi } from "vitest";
import { createKnowledgeBaseMcpServer } from "../src/mcp.js";
import type { KnowledgeBaseServices } from "../src/services.js";

const execFile = promisify(execFileCallback);
const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const bin = join(packageRoot, "dist", "cli.js");

type ReadServices = Pick<KnowledgeBaseServices, "search" | "get" | "status">;

function fakeServices(overrides: Partial<ReadServices> = {}): ReadServices {
  return {
    search: vi.fn().mockResolvedValue([{ uri: "qmd://wooto/%EB%B0%B0%ED%8F%AC.md" }]),
    get: vi.fn().mockResolvedValue({ title: "배포", body: "절차" }),
    status: vi.fn().mockResolvedValue({ healthy: true }),
    ...overrides,
  };
}

function rawMcpFrames(): Promise<{ frames: Record<string, unknown>[]; stderr: string }> {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(process.execPath, [bin, "mcp"], {
      cwd: packageRoot,
      stdio: ["pipe", "pipe", "pipe"],
    });
    const frames: Record<string, unknown>[] = [];
    let stderr = "";
    let stdout = "";
    let finished = false;
    const timeout = setTimeout(() => finish(new Error("MCP child timed out")), 2_000);

    function finish(error?: Error): void {
      if (finished) {
        return;
      }
      finished = true;
      clearTimeout(timeout);
      if (!child.killed) {
        child.kill("SIGTERM");
      }
      if (error === undefined) {
        resolvePromise({ frames, stderr });
      } else {
        rejectPromise(error);
      }
    }

    child.stderr.setEncoding("utf8");
    child.stderr.on("data", (chunk: string) => { stderr += chunk; });
    child.stdout.setEncoding("utf8");
    child.stdout.on("data", (chunk: string) => {
      stdout += chunk;
      while (true) {
        const newline = stdout.indexOf("\n");
        if (newline === -1) {
          return;
        }
        const line = stdout.slice(0, newline).replace(/\r$/, "");
        stdout = stdout.slice(newline + 1);
        if (line === "") {
          finish(new Error("MCP child emitted an empty stdout frame"));
          return;
        }

        let frame: Record<string, unknown>;
        try {
          frame = JSON.parse(line) as Record<string, unknown>;
        } catch {
          finish(new Error(`MCP child emitted non-JSON stdout: ${line}`));
          return;
        }
        frames.push(frame);

        if (frame.id === 1) {
          child.stdin.write(`${JSON.stringify({
            jsonrpc: "2.0",
            method: "notifications/initialized",
            params: {},
          })}\n`);
          child.stdin.write(`${JSON.stringify({
            jsonrpc: "2.0",
            id: 2,
            method: "tools/list",
            params: {},
          })}\n`);
        }
        if (frame.id === 2) {
          child.stdin.end();
        }
      }
    });
    child.once("error", (error) => finish(error));
    child.once("exit", () => {
      if (stdout !== "") {
        finish(new Error(`MCP child emitted an unterminated stdout frame: ${stdout}`));
      } else if (!frames.some((frame) => frame.id === 2)) {
        finish(new Error(`MCP child exited before tools/list response: ${stderr}`));
      } else {
        finish();
      }
    });

    child.stdin.write(`${JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2025-11-25",
        capabilities: {},
        clientInfo: { name: "knowledge-base-raw-test", version: "1.0.0" },
      },
    })}\n`);
  });
}

async function connect(services: ReadServices) {
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  const server = createKnowledgeBaseMcpServer(services);
  const client = new Client({ name: "knowledge-base-test", version: "1.0.0" });
  await server.connect(serverTransport);
  await client.connect(clientTransport);
  return { client, server };
}

afterEach(() => vi.restoreAllMocks());

describe("knowledge-base MCP server", () => {
  it("exposes only the read-only get, search, and status tools", async () => {
    const { client, server } = await connect(fakeServices());

    try {
      const tools = await client.listTools();

      expect(tools.tools.map((tool) => tool.name)).toEqual(["get", "search", "status"]);
      expect(tools.tools.map((tool) => tool.annotations)).toEqual([
        { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
        { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
        { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
      ]);
    } finally {
      await client.close();
      await server.close();
    }
  });

  it("calls search with validated arguments and returns text plus structured content", async () => {
    const services = fakeServices();
    const { client, server } = await connect(services);

    try {
      const result = await client.callTool({
        name: "search",
        arguments: { query: "배포", scope: "wooto", limit: 3 },
      });

      expect(services.search).toHaveBeenCalledWith("배포", "wooto", 3);
      expect(result.isError).toBeUndefined();
      expect(result.structuredContent).toEqual({
        result: [{ uri: "qmd://wooto/%EB%B0%B0%ED%8F%AC.md" }],
      });
      expect(result.content).toEqual([{
        type: "text",
        text: JSON.stringify([{ uri: "qmd://wooto/%EB%B0%B0%ED%8F%AC.md" }]),
      }]);
    } finally {
      await client.close();
      await server.close();
    }
  });

  it("uses all and 10 as omitted search scope and limit defaults", async () => {
    const services = fakeServices();
    const { client, server } = await connect(services);

    try {
      await client.callTool({ name: "search", arguments: { query: "배포" } });

      expect(services.search).toHaveBeenCalledWith("배포", "all", 10);
    } finally {
      await client.close();
      await server.close();
    }
  });

  it("rejects unknown properties and invalid scope or limits before calling search", async () => {
    const services = fakeServices();
    const { client, server } = await connect(services);

    try {
      for (const arguments_ of [
        { query: "배포", unexpected: true },
        { query: "배포", scope: "shared" },
        { query: "배포", limit: 0 },
        { query: "배포", limit: 51 },
      ]) {
        await expect(client.callTool({ name: "search", arguments: arguments_ })).resolves.toMatchObject({
          isError: true,
          content: [{ type: "text", text: expect.stringContaining("MCP error -32602") }],
        });
      }

      expect(services.search).not.toHaveBeenCalled();
    } finally {
      await client.close();
      await server.close();
    }
  });

  it("passes canonical retrieval and line constraints through to get", async () => {
    const services = fakeServices();
    const { client, server } = await connect(services);

    try {
      await client.callTool({
        name: "get",
        arguments: { ref: "qmd://personal/%EB%B0%B0%ED%8F%AC.md", fromLine: 2, maxLines: 1000 },
      });

      expect(services.get).toHaveBeenCalledWith("qmd://personal/%EB%B0%B0%ED%8F%AC.md", 2, 1000);
      await expect(client.callTool({
        name: "get",
        arguments: { ref: "qmd://personal/guide.md", maxLines: 1001 },
      })).resolves.toMatchObject({
        isError: true,
        content: [{ type: "text", text: expect.stringContaining("MCP error -32602") }],
      });
      await expect(client.callTool({
        name: "get",
        arguments: { ref: "qmd://personal/guide.md", extra: true },
      })).resolves.toMatchObject({
        isError: true,
        content: [{ type: "text", text: expect.stringContaining("MCP error -32602") }],
      });
      expect(services.get).toHaveBeenCalledOnce();
    } finally {
      await client.close();
      await server.close();
    }
  });

  it("returns operational failures in the MCP tool error envelope", async () => {
    const services = fakeServices({ status: vi.fn().mockRejectedValue(new Error("search store unavailable")) });
    const { client, server } = await connect(services);

    try {
      await expect(client.callTool({ name: "status", arguments: {} })).resolves.toMatchObject({
        isError: true,
        content: [{ type: "text", text: "search store unavailable" }],
      });
    } finally {
      await client.close();
      await server.close();
    }
  });

  it("passes an empty strict status request to the status service", async () => {
    const services = fakeServices();
    const { client, server } = await connect(services);

    try {
      await expect(client.callTool({ name: "status", arguments: {} })).resolves.toMatchObject({
        structuredContent: { result: { healthy: true } },
      });
      await expect(client.callTool({ name: "status", arguments: { extra: true } })).resolves.toMatchObject({
        isError: true,
        content: [{ type: "text", text: expect.stringContaining("MCP error -32602") }],
      });
      expect(services.status).toHaveBeenCalledOnce();
    } finally {
      await client.close();
      await server.close();
    }
  });
});

describe("knowledge-base mcp CLI", () => {
  beforeAll(async () => {
    await execFile(process.execPath, [
      join(packageRoot, "node_modules", "typescript", "bin", "tsc"),
      "-p",
      join(packageRoot, "tsconfig.json"),
    ]);
  });

  it("emits only JSON-RPC initialize and tools-list frames on raw child stdout", async () => {
    const { frames, stderr } = await rawMcpFrames();

    expect(stderr).toBe("");
    expect(frames.map((frame) => frame.id)).toEqual([1, 2]);
    expect(frames).toEqual([
      expect.objectContaining({
        jsonrpc: "2.0",
        id: 1,
        result: expect.objectContaining({ protocolVersion: "2025-11-25" }),
      }),
      expect.objectContaining({
        jsonrpc: "2.0",
        id: 2,
        result: expect.objectContaining({
          tools: expect.arrayContaining([
            expect.objectContaining({ name: "get" }),
            expect.objectContaining({ name: "search" }),
            expect.objectContaining({ name: "status" }),
          ]),
        }),
      }),
    ]);
  });
});
