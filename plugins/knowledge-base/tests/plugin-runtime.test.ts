import { execFile as execFileCallback } from "node:child_process";
import { readFileSync } from "node:fs";
import { access, cp, mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import type { Readable } from "node:stream";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { afterEach, describe, expect, it } from "vitest";

const enabled = process.env.KNOWLEDGE_BASE_REAL_PLUGIN === "1";
const pluginRuntimeTest = enabled ? it : it.skip;
const execFile = promisify(execFileCallback);
const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const expectedVersion = (JSON.parse(
  readFileSync(join(packageRoot, "package.json"), "utf8"),
) as { version: string }).version;
const temporaryRoots: string[] = [];
const originalEnvironment = { ...process.env };
const publicPluginFiles = ["bin", "dist", "package.json", "package-lock.json", "README.md", "LICENSE"];

afterEach(async () => {
  for (const key of Object.keys(process.env)) {
    if (!(key in originalEnvironment)) delete process.env[key];
  }
  Object.assign(process.env, originalEnvironment);
  while (temporaryRoots.length > 0) {
    await rm(temporaryRoots.pop()!, { recursive: true, force: true });
  }
});

describe("plugin-local runtime", () => {
  pluginRuntimeTest("bootstraps dependencies and serves MCP from a fresh copy", async () => {
    const fixture = await copyPublicPluginFixture();
    const launcher = join(fixture, "bin", "knowledge-base.mjs");

    expect(await pathExists(join(fixture, "node_modules"))).toBe(false);

    const version = await execFile(process.execPath, [launcher, "--version"], {
      env: isolatedEnvironment(fixture),
      timeout: 10 * 60_000,
    });
    expect(version.stderr).toBe("");
    expect(version.stdout).toBe(`${expectedVersion}\n`);
    expect(await pathExists(join(fixture, "node_modules", "@tobilu", "qmd"))).toBe(true);

    const transport = new StdioClientTransport({
      command: process.execPath,
      args: [launcher, "mcp"],
      env: isolatedEnvironment(fixture),
      stderr: "pipe",
    });
    const client = new Client({
      name: "knowledge-base-plugin-runtime",
      version: "1.0.0",
    });
    const stderr = transport.stderr as Readable | null;
    if (stderr === null) throw new Error("MCP child stderr was not captured");

    let stderrOutput = "";
    const stderrDone = new Promise<void>((resolvePromise, rejectPromise) => {
      stderr.setEncoding("utf8");
      stderr.on("data", (chunk: string) => { stderrOutput += chunk; });
      stderr.once("end", resolvePromise);
      stderr.once("error", rejectPromise);
    });
    let rejectProtocol: (error: Error) => void;
    const protocolFailure = new Promise<never>((_, rejectPromise) => {
      rejectProtocol = rejectPromise;
    });
    transport.onerror = (error) => rejectProtocol(error);

    let failure: unknown;
    let cleanupFailure: unknown;
    try {
      await withDeadline(client.connect(transport), "MCP initialize", protocolFailure);
      const { tools } = await withDeadline(client.listTools(), "MCP tools/list", protocolFailure);
      expect(tools.map((tool) => tool.name).sort()).toEqual(["get", "search", "status"]);
      expect(client.getServerVersion()).toEqual({
        name: "knowledge-base",
        version: expectedVersion,
      });
    } catch (error) {
      failure = error;
    } finally {
      try {
        await withDeadline(client.close(), "MCP close");
      } catch (error) {
        cleanupFailure = error;
      }
      try {
        await withDeadline(stderrDone, "MCP stderr drain");
      } catch (error) {
        if (cleanupFailure === undefined) cleanupFailure = error;
      }
    }

    if (failure !== undefined) throw failure;
    if (cleanupFailure !== undefined) throw cleanupFailure;
    expect(stderrOutput).toBe("");
  }, 15 * 60_000);
});

async function copyPublicPluginFixture(): Promise<string> {
  const fixture = await mkdtemp(join(tmpdir(), "knowledge-base-plugin-runtime-"));
  temporaryRoots.push(fixture);
  await Promise.all(publicPluginFiles.map((file) => cp(join(packageRoot, file), join(fixture, file), {
    recursive: true,
  })));
  return fixture;
}

function isolatedEnvironment(root: string): NodeJS.ProcessEnv {
  return {
    ...process.env,
    KNOWLEDGE_BASE_CONFIG_DIR: join(root, "config"),
    KNOWLEDGE_BASE_DATA_DIR: join(root, "data"),
    KNOWLEDGE_BASE_CACHE_DIR: join(root, "cache"),
    npm_config_cache: join(root, "npm-cache"),
  };
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

async function withDeadline<T>(
  operation: Promise<T>,
  name: string,
  protocolFailure?: Promise<never>,
): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<T>((_, rejectPromise) => {
    timer = setTimeout(() => rejectPromise(new Error(`${name} timed out`)), 2_000);
  });
  const contenders = protocolFailure === undefined ? [operation, timeout] : [operation, timeout, protocolFailure];
  return await Promise.race(contenders).finally(() => {
    if (timer !== undefined) clearTimeout(timer);
  });
}
