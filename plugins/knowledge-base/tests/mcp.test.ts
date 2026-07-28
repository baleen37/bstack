import { execFile as execFileCallback } from "node:child_process";
import { dirname, join, resolve } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
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

  it("starts the stdio server through the mcp command without polluting stdout", async () => {
    const transport = new StdioClientTransport({
      command: process.execPath,
      args: [bin, "mcp"],
      cwd: packageRoot,
      stderr: "pipe",
    });
    const client = new Client({ name: "knowledge-base-child-test", version: "1.0.0" });

    try {
      await client.connect(transport);
      expect((await client.listTools()).tools.map((tool) => tool.name)).toEqual(["get", "search", "status"]);
    } finally {
      await client.close();
    }
  });
});
