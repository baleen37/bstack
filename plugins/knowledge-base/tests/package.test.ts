import { execFile } from "node:child_process";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { describe, expect, it } from "vitest";
import { readPackageVersion } from "../src/package-version.js";

const execFileAsync = promisify(execFile);
const packageDir = fileURLToPath(new URL("../", import.meta.url));
const publicDistModules = [
  "cli",
  "config",
  "mcp",
  "model",
  "model-io",
  "model-verify",
  "package-version",
  "paths",
  "process",
  "qmd",
  "repository",
  "runtime-bootstrap",
  "services",
  "types",
];
const publicPackageFiles = [
  "bin/knowledge-base.mjs",
  "README.md",
  "LICENSE",
  "package.json",
  ...publicDistModules.flatMap((module) => [
    `dist/${module}.d.ts`,
    `dist/${module}.js`,
    `dist/${module}.js.map`,
  ]),
].sort();

describe("published package", () => {
  it.each([
    ["a missing package file", undefined],
    ["malformed package JSON", "{"],
  ])("fails clearly for %s", async (_case, contents) => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-base-package-"));
    const file = join(root, "package.json");
    if (contents !== undefined) {
      await writeFile(file, contents);
    }

    expect(() => readPackageVersion(file))
      .toThrow("package version is unavailable");
  });

  it("contains only the public CLI artifact and package documents", async () => {
    const { stdout } = await execFileAsync("npm", ["pack", "--dry-run", "--json"], {
      cwd: packageDir,
    });
    const packed = JSON.parse(stdout) as
      | Array<{ files: Array<{ path: string }> }>
      | Record<string, { files: Array<{ path: string }> }>;
    const entry = Array.isArray(packed) ? packed[0] : Object.values(packed)[0];
    const files = entry?.files.map((file) => file.path) ?? [];

    expect(files.sort()).toEqual(publicPackageFiles);
  });
});
