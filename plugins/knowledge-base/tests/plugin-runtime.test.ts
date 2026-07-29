import { execFile as execFileCallback } from "node:child_process";
import { readFileSync } from "node:fs";
import { access, cp, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
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
  pluginRuntimeTest("first-launches MCP inside a parent workspace and loads native dependencies", async () => {
    const { fixture, parentRoot, externalRoot, parentPackage } = await copyWorkspacePluginFixture();
    const launcher = join(fixture, "bin", "knowledge-base.mjs");
    const childEnvironment = isolatedEnvironment(fixture, externalRoot);

    expect(await pathExists(join(parentRoot, "node_modules"))).toBe(false);
    expect(await pathExists(join(fixture, "node_modules"))).toBe(false);

    const transport = new StdioClientTransport({
      command: process.execPath,
      args: [launcher, "mcp"],
      env: childEnvironment,
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
      await withDeadline(client.connect(transport), "first-launch MCP initialize", 12 * 60_000, protocolFailure);
      const { tools } = await withDeadline(client.listTools(), "MCP tools/list", 10_000, protocolFailure);
      expect(tools.map((tool) => tool.name).sort()).toEqual(["get", "search", "status"]);
      expect(client.getServerVersion()).toEqual({
        name: "knowledge-base",
        version: expectedVersion,
      });
    } catch (error) {
      failure = error;
    } finally {
      try {
        await withDeadline(client.close(), "MCP close", 10_000);
      } catch (error) {
        cleanupFailure = error;
      }
      try {
        await withDeadline(stderrDone, "MCP stderr drain", 10_000);
      } catch (error) {
        if (cleanupFailure === undefined) cleanupFailure = error;
      }
    }

    if (failure !== undefined) throw failure;
    if (cleanupFailure !== undefined) throw cleanupFailure;
    expect(stderrOutput).toBe("");

    expect(await pathExists(join(fixture, "node_modules", "@tobilu", "qmd"))).toBe(true);
    expect(await pathExists(join(fixture, ".knowledge-base-runtime", "ready.json"))).toBe(true);
    expect(await pathExists(join(fixture, ".knowledge-base-runtime", "cache", "npm"))).toBe(true);
    const runtimeEntries = await readdir(join(fixture, ".knowledge-base-runtime"));
    expect(runtimeEntries.some((entry) =>
      /^(?:bootstrap(?:\.lock|-owner-)|install-|node_modules-backup-)/.test(entry)
    )).toBe(false);
    expect(await pathExists(join(parentRoot, "node_modules"))).toBe(false);
    expect(await pathExists(join(parentRoot, "package-lock.json"))).toBe(false);
    expect(await readFile(join(parentRoot, "package.json"), "utf8")).toBe(parentPackage);
    expect(await pathExists(externalRoot)).toBe(false);

    const nativeLoad = await execFile(process.execPath, [
      "--input-type=module",
      "-e",
      `import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
const requireFromRoot = createRequire(pathToFileURL(process.argv[1] + "/package.json"));
const Database = requireFromRoot("better-sqlite3");
const database = new Database(":memory:");
requireFromRoot("sqlite-vec").load(database);
const llama = await import(pathToFileURL(requireFromRoot.resolve("node-llama-cpp")).href);
database.close();
if (typeof llama.getLlama !== "function") throw new Error("node-llama-cpp failed to load");
console.log("native runtime loaded");`,
      fixture,
    ], {
      env: childEnvironment,
      timeout: 60_000,
    });
    expect(nativeLoad.stderr).toBe("");
    expect(nativeLoad.stdout).toBe("native runtime loaded\n");

    const version = await execFile(process.execPath, [launcher, "--version"], {
      env: {
        ...childEnvironment,
        PATH: join(parentRoot, "npm-must-not-run"),
      },
      timeout: 30_000,
    });
    expect(version.stderr).toBe("");
    expect(version.stdout).toBe(`${expectedVersion}\n`);
  }, 15 * 60_000);
});

async function copyWorkspacePluginFixture(): Promise<{
  fixture: string;
  parentRoot: string;
  externalRoot: string;
  parentPackage: string;
}> {
  const parentRoot = await mkdtemp(join(tmpdir(), "knowledge base plugin workspace-"));
  temporaryRoots.push(parentRoot);
  const fixture = join(parentRoot, "plugins", "knowledge-base");
  const externalRoot = join(parentRoot, "external-writes");
  const parentPackage = `${JSON.stringify({
    name: "parent-workspace",
    private: true,
    workspaces: ["plugins/*"],
  }, null, 2)}\n`;
  await mkdir(fixture, { recursive: true });
  await writeFile(join(parentRoot, "package.json"), parentPackage);
  await Promise.all(publicPluginFiles.map((file) => cp(join(packageRoot, file), join(fixture, file), {
    recursive: true,
  })));
  return { fixture, parentRoot, externalRoot, parentPackage };
}

function isolatedEnvironment(root: string, externalRoot: string): NodeJS.ProcessEnv {
  return {
    ...process.env,
    KNOWLEDGE_BASE_CONFIG_DIR: join(root, ".test-data", "config"),
    KNOWLEDGE_BASE_DATA_DIR: join(root, ".test-data", "data"),
    KNOWLEDGE_BASE_CACHE_DIR: join(root, ".test-data", "cache"),
    HOME: join(externalRoot, "home"),
    USERPROFILE: join(externalRoot, "user-profile"),
    TMPDIR: join(externalRoot, "tmpdir"),
    TMP: join(externalRoot, "tmp"),
    TEMP: join(externalRoot, "temp"),
    XDG_CACHE_HOME: join(externalRoot, "xdg-cache"),
    XDG_CONFIG_HOME: join(externalRoot, "xdg-config"),
    XDG_DATA_HOME: join(externalRoot, "xdg-data"),
    XDG_STATE_HOME: join(externalRoot, "xdg-state"),
    npm_config_cache: join(externalRoot, "npm-cache"),
    npm_config_devdir: join(externalRoot, "node-gyp"),
    CCACHE_DIR: join(externalRoot, "ccache"),
    NODE_LLAMA_CPP_XPACKS_STORE_FOLDER: join(externalRoot, "llama-store"),
    NODE_LLAMA_CPP_XPACKS_CACHE_FOLDER: join(externalRoot, "llama-cache"),
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
  timeoutMs: number,
  protocolFailure?: Promise<never>,
): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<T>((_, rejectPromise) => {
    timer = setTimeout(() => rejectPromise(new Error(`${name} timed out`)), timeoutMs);
  });
  const contenders = protocolFailure === undefined ? [operation, timeout] : [operation, timeout, protocolFailure];
  return await Promise.race(contenders).finally(() => {
    if (timer !== undefined) clearTimeout(timer);
  });
}
