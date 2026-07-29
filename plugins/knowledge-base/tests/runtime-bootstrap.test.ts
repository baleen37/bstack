import { mkdirSync } from "node:fs";
import { mkdtemp, mkdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { bootstrapRuntimeDependencies } from "../src/runtime-bootstrap.js";

const runtimeDependencies = [
  "@modelcontextprotocol/sdk",
  "@tobilu/qmd",
  "zod",
];
const roots: string[] = [];

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
      }),
    );
  });

  it("preserves npm stderr and fails when bootstrap cannot complete", async () => {
    const root = await runtimeRoot();
    const write = vi.spyOn(process.stderr, "write").mockImplementation(() => true);
    const runner = vi.fn(() => ({ status: 42, stderr: "native install failed\n" }));

    expect(() => bootstrapRuntimeDependencies(root, runner as never))
      .toThrow("Failed to install knowledge-base runtime dependencies.");
    expect(write).toHaveBeenCalledWith("native install failed\n");
  });
});
