import { execFile as execFileCallback } from "node:child_process";
import { readFileSync } from "node:fs";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { promisify } from "node:util";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { beforeAll, describe, expect, it, vi } from "vitest";
import { main } from "../src/cli.js";
import type { KnowledgeBaseServices } from "../src/services.js";

const execFile = promisify(execFileCallback);
const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const bin = join(packageRoot, "dist", "cli.js");
const expectedVersion = (JSON.parse(
  readFileSync(join(packageRoot, "package.json"), "utf8"),
) as { version: string }).version;

function fakeServices(): KnowledgeBaseServices {
  return {
    setup: vi.fn(),
    pull: vi.fn(),
    index: vi.fn(),
    search: vi.fn(),
    get: vi.fn(),
    status: vi.fn(),
    startMcp: vi.fn(),
  };
}

beforeAll(async () => {
  await execFile(process.execPath, [
    join(packageRoot, "node_modules", "typescript", "bin", "tsc"),
    "-p",
    join(packageRoot, "tsconfig.json"),
  ]);
});

describe("knowledge-base binary entrypoint", () => {
  it("runs the exported CLI main without requiring the file to be the entrypoint", async () => {
    const stdout: string[] = [];
    const stderr: string[] = [];
    const services = fakeServices();

    await expect(main(["--version"], services, {
      stdout: (text) => stdout.push(text),
      stderr: (text) => stderr.push(text),
    })).resolves.toBe(0);

    expect(stdout).toEqual([`${expectedVersion}\n`]);
    expect(stderr).toEqual([]);
  });

  it("runs when Node executes a symlink to the binary", async () => {
    const directory = await mkdtemp(join(tmpdir(), "knowledge-base-bin-"));
    const link = join(directory, "knowledge-base");
    await symlink(bin, link);

    try {
      const { stdout, stderr } = await execFile(process.execPath, [link, "--version"]);

      expect(stderr).toBe("");
      expect(stdout).toBe(`${expectedVersion}\n`);
    } finally {
      await rm(directory, { recursive: true, force: true });
    }
  });
});
