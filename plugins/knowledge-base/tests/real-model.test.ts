import { mkdir, mkdtemp, open, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { saveConfig } from "../src/config.js";
import { ensureModel } from "../src/model.js";
import { resolvePaths } from "../src/paths.js";
import { createServices } from "../src/services.js";
import type { Scope } from "../src/types.js";

const enabled = process.env.KNOWLEDGE_BASE_REAL_MODEL === "1";
const realModelTest = enabled ? it : it.skip;

interface EvalRecord {
  query: string;
  scope: Scope;
  expectedUri: string;
  maxRank: number;
}

interface Fixture {
  checkout: string;
  records: EvalRecord[];
}

const temporaryRoots: string[] = [];
const originalEnvironment = { ...process.env };

afterEach(async () => {
  for (const key of Object.keys(process.env)) {
    if (!(key in originalEnvironment)) delete process.env[key];
  }
  Object.assign(process.env, originalEnvironment);
  while (temporaryRoots.length > 0) {
    await rm(temporaryRoots.pop()!, { recursive: true, force: true });
  }
});

describe("real embedding model", () => {
  realModelTest("downloads, indexes, searches, and rejects a corrupted verified artifact", async () => {
    const fixture = await loadFixture();
    const temporaryRoot = await mkdtemp(join(tmpdir(), "knowledge-base-real-model-"));
    temporaryRoots.push(temporaryRoot);
    const configDir = join(temporaryRoot, "config");
    const dataDir = join(temporaryRoot, "data");
    const cacheDir = join(temporaryRoot, "cache");
    Object.assign(process.env, {
      KNOWLEDGE_BASE_CONFIG_DIR: configDir,
      KNOWLEDGE_BASE_DATA_DIR: dataDir,
      KNOWLEDGE_BASE_CACHE_DIR: cacheDir,
    });

    const repository = "fixture/knowledge-base";
    const paths = resolvePaths(process.env, process.platform, temporaryRoot, repository);
    await saveConfig(paths.configFile, {
      repository,
      checkoutPath: fixture.checkout,
      defaultScope: "all",
    });
    await ensureModel(paths.modelFile);

    const services = createServices();
    await services.index("all", true);
    for (const record of fixture.records) {
      const results = await services.search(record.query, record.scope, record.maxRank);
      expect(results.findIndex((result) => result.uri === record.expectedUri) + 1)
        .toBeGreaterThan(0);
      expect(results.findIndex((result) => result.uri === record.expectedUri) + 1)
        .toBeLessThanOrEqual(record.maxRank);
    }

    expect(await findGgufFiles(cacheDir)).toEqual([paths.modelFile]);
    await corruptOneByte(paths.modelFile);
    await expect(services.search(fixture.records[0]!.query, fixture.records[0]!.scope, 3))
      .rejects.toThrow("model SHA-256 mismatch");
  }, 20 * 60_000);
});

async function loadFixture(): Promise<Fixture> {
  const checkout = process.env.KNOWLEDGE_BASE_CHECKOUT;
  const evalFile = process.env.KNOWLEDGE_BASE_EVAL_FILE;
  if (checkout !== undefined && evalFile !== undefined) {
    const records = JSON.parse(await readFile(evalFile, "utf8")) as EvalRecord[];
    return { checkout, records };
  }

  const root = await mkdtemp(join(tmpdir(), "knowledge-base-real-fixture-"));
  temporaryRoots.push(root);
  await mkdir(join(root, "personal"), { recursive: true });
  await mkdir(join(root, "wooto"), { recursive: true });
  await writeFile(join(root, "personal", "README.md"), "# 개인 지식\n개인 지식에는 배운 내용과 기록을 남긴다.\n");
  await writeFile(join(root, "wooto", "repositories.md"), "# Wooto 저장소\nWooto의 핵심 코드 저장소와 위치를 안내한다.\n");
  return {
    checkout: root,
    records: [
      {
        query: "Wooto의 핵심 코드 저장소",
        scope: "wooto",
        expectedUri: "qmd://wooto/repositories.md",
        maxRank: 3,
      },
      {
        query: "개인 지식에는 무엇을 기록해야 하나?",
        scope: "personal",
        expectedUri: "qmd://personal/README.md",
        maxRank: 3,
      },
    ],
  };
}

async function findGgufFiles(directory: string): Promise<string[]> {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map(async (entry) => {
    const file = join(directory, entry.name);
    if (entry.isDirectory()) return findGgufFiles(file);
    return entry.isFile() && entry.name.endsWith(".gguf") ? [file] : [];
  }));
  return files.flat().sort();
}

async function corruptOneByte(file: string): Promise<void> {
  await mkdir(dirname(file), { recursive: true });
  const handle = await open(file, "r+");
  try {
    const byte = Buffer.alloc(1);
    await handle.read(byte, 0, 1, 128);
    byte[0] = byte[0]! ^ 0xff;
    await handle.write(byte, 0, 1, 128);
    await handle.sync();
  } finally {
    await handle.close();
  }
}
