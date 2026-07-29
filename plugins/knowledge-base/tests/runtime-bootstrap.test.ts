import { execFile as execFileCallback } from "node:child_process";
import { mkdirSync } from "node:fs";
import { copyFile, mkdtemp, mkdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { afterEach, describe, expect, it, vi } from "vitest";
import { bootstrapRuntimeDependencies } from "../src/runtime-bootstrap.js";

const runtimeDependencies = [
  "@modelcontextprotocol/sdk",
  "@tobilu/qmd",
  "zod",
];
const roots: string[] = [];
const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const execFile = promisify(execFileCallback);
const nativeRuntimeTest = process.env.KNOWLEDGE_BASE_RUNTIME_INTEGRATION === "1" ? it : it.skip;

async function runtimeRoot(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "knowledge-base-runtime-"));
  roots.push(root);
  return root;
}

async function createDependencyDirectories(root: string): Promise<void> {
  await Promise.all(runtimeDependencies.map((dependency) =>
    mkdir(join(root, "node_modules", dependency), { recursive: true }),
  ));
}

function createDependencyDirectoriesSync(root: string): void {
  for (const dependency of runtimeDependencies) {
    mkdirSync(join(root, "node_modules", dependency), { recursive: true });
  }
}

afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

describe("knowledge-base runtime bootstrap", () => {
  it("skips npm when all direct runtime dependencies exist", async () => {
    const root = await runtimeRoot();
    await createDependencyDirectories(root);
    const runner = vi.fn();

    bootstrapRuntimeDependencies(root, runner as never);

    expect(runner).not.toHaveBeenCalled();
  });

  it("runs deterministic production npm ci when a dependency is missing", async () => {
    const root = await runtimeRoot();
    const runner = vi.fn(() => {
      createDependencyDirectoriesSync(root);
      return { status: 0, stderr: "" };
    });

    bootstrapRuntimeDependencies(root, runner as never);

    expect(runner).toHaveBeenCalledWith(
      process.platform === "win32" ? "npm.cmd" : "npm",
      ["ci", "--omit=dev", "--legacy-peer-deps", "--no-audit", "--no-fund"],
      expect.objectContaining({
        cwd: root,
        encoding: "utf8",
        stdio: ["ignore", "ignore", "pipe"],
        env: expect.objectContaining({
          npm_config_dangerously_allow_all_scripts: "true",
          npm_config_ignore_scripts: "false",
        }),
      }),
    );
  });

  nativeRuntimeTest("installs native qmd dependencies that load in a clean runtime root", async () => {
    const root = await runtimeRoot();
    await Promise.all([
      copyFile(join(packageRoot, "package.json"), join(root, "package.json")),
      copyFile(join(packageRoot, "package-lock.json"), join(root, "package-lock.json")),
    ]);

    bootstrapRuntimeDependencies(root);

    const { stdout, stderr } = await execFile(process.execPath, [
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
      root,
    ]);

    expect(stderr).toBe("");
    expect(stdout).toBe("native runtime loaded\n");
  }, 10 * 60_000);

  it("preserves npm stderr and fails when bootstrap cannot complete", async () => {
    const root = await runtimeRoot();
    const write = vi.spyOn(process.stderr, "write").mockImplementation(() => true);
    const runner = vi.fn(() => ({ status: 42, stderr: "native install failed\n" }));

    expect(() => bootstrapRuntimeDependencies(root, runner as never))
      .toThrow("Failed to install knowledge-base runtime dependencies.");
    expect(write).toHaveBeenCalledWith("native install failed\n");
  });
});
