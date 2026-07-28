import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { loadConfig, saveConfig } from "../src/config.js";
import { resolvePaths } from "../src/paths.js";

describe("config", () => {
  it("uses explicit config and cache roots", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-base-config-"));
    const paths = resolvePaths(
      {
        KNOWLEDGE_BASE_CONFIG_DIR: join(root, "config"),
        KNOWLEDGE_BASE_DATA_DIR: join(root, "data"),
        KNOWLEDGE_BASE_CACHE_DIR: join(root, "cache"),
      },
      "linux",
      root,
      "baleen37/knowledge-base",
    );

    expect(paths.repositoryDir).toBe(
      join(root, "data", "repositories", "baleen37", "knowledge-base"),
    );
  });

  it("round-trips a strict config atomically", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-base-save-"));
    const file = join(root, "config.json");
    const config = {
      repository: "baleen37/knowledge-base",
      checkoutPath: "/tmp/knowledge-base",
      defaultScope: "all" as const,
    };

    await saveConfig(file, config);

    expect(await loadConfig(file)).toEqual(config);
    expect(JSON.parse(await readFile(file, "utf8"))).toEqual(config);
  });
});
