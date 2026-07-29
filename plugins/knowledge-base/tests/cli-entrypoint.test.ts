import { execFile as execFileCallback } from "node:child_process";
import { readFileSync } from "node:fs";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { promisify } from "node:util";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { beforeAll, describe, expect, it } from "vitest";

const execFile = promisify(execFileCallback);
const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const bin = join(packageRoot, "dist", "cli.js");
const expectedVersion = (JSON.parse(
  readFileSync(join(packageRoot, "package.json"), "utf8"),
) as { version: string }).version;

beforeAll(async () => {
  await execFile(process.execPath, [
    join(packageRoot, "node_modules", "typescript", "bin", "tsc"),
    "-p",
    join(packageRoot, "tsconfig.json"),
  ]);
});

describe("knowledge-base binary entrypoint", () => {
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
