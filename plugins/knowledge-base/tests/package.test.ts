import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { describe, expect, it } from "vitest";

const execFileAsync = promisify(execFile);
const packageDir = fileURLToPath(new URL("../", import.meta.url));

describe("published package", () => {
  it("contains only the public CLI artifact and package documents", async () => {
    const { stdout } = await execFileAsync("npm", ["pack", "--dry-run", "--json"], {
      cwd: packageDir,
    });
    const packed = JSON.parse(stdout) as
      | Array<{ files: Array<{ path: string }> }>
      | Record<string, { files: Array<{ path: string }> }>;
    const entry = Array.isArray(packed) ? packed[0] : Object.values(packed)[0];
    const files = entry?.files.map((file) => file.path) ?? [];

    for (const forbidden of [
      "personal/",
      "wooto/",
      ".sqlite",
      ".gguf",
      "config.json",
    ]) {
      expect(files.some((file) => file.includes(forbidden))).toBe(false);
    }
    expect(files).toContain("dist/cli.js");
    expect(files).toContain("README.md");
    expect(files).toContain("LICENSE");
  });
});
