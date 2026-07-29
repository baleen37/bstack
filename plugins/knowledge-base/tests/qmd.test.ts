import { access, mkdir, mkdtemp, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  getKnowledge,
  getKnowledgeStatus,
  indexKnowledge,
  openIndexStore,
  openSearchStore,
  searchKnowledge,
} from "../src/qmd.js";
import type { ResolvedPaths } from "../src/types.js";

const createStore = vi.hoisted(() => vi.fn());
const extractSnippet = vi.hoisted(() => vi.fn());
const verifyModelFile = vi.hoisted(() => vi.fn());

vi.mock("@tobilu/qmd", () => ({ createStore, extractSnippet }));
vi.mock("../src/model-verify.js", () => ({ verifyModelFile }));

function fakeStore() {
  return {
    search: vi.fn().mockResolvedValue([]),
    update: vi.fn(),
    embed: vi.fn(),
    get: vi.fn(),
    getDocumentBody: vi.fn(),
    getStatus: vi.fn(),
    getIndexHealth: vi.fn(),
    close: vi.fn().mockResolvedValue(undefined),
  };
}

function paths(root: string): ResolvedPaths {
  return {
    configDir: join(root, "config"),
    configFile: join(root, "config", "config.json"),
    dataDir: join(root, "data"),
    cacheDir: join(root, "cache"),
    repositoryDir: join(root, "repository"),
    indexFile: join(root, "cache", "indexes", "knowledge.sqlite"),
    modelFile: join(root, "cache", "models", "embedding.gguf"),
    disabledGenerateModel: join(root, "cache", "disabled", "generate.gguf"),
    disabledRerankModel: join(root, "cache", "disabled", "rerank.gguf"),
  };
}

function searchResult(file: string) {
  return {
    file,
    displayPath: "personal/배포 절차.md",
    title: "배포 절차",
    body: "첫 줄\n배포 절차를 확인합니다.",
    bestChunk: "배포 절차를 확인합니다.",
    bestChunkPos: 4,
    score: 0.75,
    context: null,
    docid: "abc123",
  };
}

afterEach(() => {
  createStore.mockReset();
  extractSnippet.mockReset();
  verifyModelFile.mockReset();
  delete process.env.QMD_EMBED_MODEL;
  delete process.env.QMD_GENERATE_MODEL;
  delete process.env.QMD_RERANK_MODEL;
});

describe("qmd adapter", () => {
  it("omits collections for all scope", async () => {
    const store = fakeStore();

    await searchKnowledge(store as never, "배포 절차", "all", 10);

    expect(store.search).toHaveBeenCalledWith({
      queries: [
        { type: "lex", query: "배포 절차" },
        { type: "vec", query: "배포 절차" },
      ],
      rerank: false,
      limit: 10,
    });
  });

  it("passes exactly one collection for a single scope", async () => {
    const store = fakeStore();

    await searchKnowledge(store as never, "개인 규칙", "personal", 5);

    expect(store.search).toHaveBeenCalledWith(expect.objectContaining({
      collections: ["personal"],
      rerank: false,
    }));
  });

  it("rejects an empty query before searching", async () => {
    const store = fakeStore();

    await expect(searchKnowledge(store as never, "  ", "all", 10))
      .rejects.toThrow("invalid_query");
    expect(store.search).not.toHaveBeenCalled();
  });

  it.each([0, 51, 1.5])("rejects an invalid search limit of %s", async (limit) => {
    const store = fakeStore();

    await expect(searchKnowledge(store as never, "배포", "all", limit))
      .rejects.toThrow("invalid_limit");
    expect(store.search).not.toHaveBeenCalled();
  });

  it("normalizes qmd results into canonical encoded URIs and snippets", async () => {
    const store = fakeStore();
    store.search.mockResolvedValue([searchResult("qmd://personal/배포 절차.md")]);
    extractSnippet.mockReturnValue({ line: 2, snippet: "배포 절차를 확인합니다." });

    await expect(searchKnowledge(store as never, "배포 절차", "all", 10)).resolves.toEqual([
      {
        collection: "personal",
        uri: "qmd://personal/%EB%B0%B0%ED%8F%AC%20%EC%A0%88%EC%B0%A8.md",
        docid: "abc123",
        title: "배포 절차",
        line: 2,
        snippet: "배포 절차를 확인합니다.",
        score: 0.75,
      },
    ]);
    expect(extractSnippet).toHaveBeenCalledWith(
      "첫 줄\n배포 절차를 확인합니다.",
      "배포 절차",
      500,
      4,
      "배포 절차를 확인합니다.".length,
    );
  });

  it("rejects a search result that is not a permitted qmd URI", async () => {
    const store = fakeStore();
    store.search.mockResolvedValue([searchResult("personal/배포 절차.md")]);

    await expect(searchKnowledge(store as never, "배포 절차", "all", 10))
      .rejects.toThrow("invalid_result_uri");
  });

  it("uses explicit hybrid queries without an LLM reranker", async () => {
    const store = fakeStore();

    await searchKnowledge(store as never, "배포", "all", 10);

    expect(store.search).not.toHaveBeenCalledWith(
      expect.objectContaining({ query: expect.any(String) }),
    );
    expect(store.search).toHaveBeenCalledWith(
      expect.objectContaining({ queries: expect.any(Array), rerank: false }),
    );
  });

  it("updates and embeds only the requested scope with the verified model", async () => {
    const store = fakeStore();
    const update = { collections: 1, indexed: 1, updated: 0, unchanged: 0, removed: 0, needsEmbedding: 1 };
    const embedded = { embedded: 1, failed: [] };
    store.update.mockResolvedValue(update);
    store.embed.mockResolvedValue(embedded);

    await expect(indexKnowledge(store as never, "personal", true, "/models/embed.gguf"))
      .resolves.toEqual({ update, embedded: [embedded] });
    expect(store.update).toHaveBeenCalledWith({ collections: ["personal"] });
    expect(store.embed).toHaveBeenCalledWith({
      collection: "personal",
      force: true,
      model: "/models/embed.gguf",
    });
  });

  it.each(["models/embed.gguf", "hf:org/embed.gguf"])
    ("rejects an untrusted model path before embedding: %s", async (modelPath) => {
      const store = fakeStore();

      await expect(indexKnowledge(store as never, "personal", false, modelPath))
        .rejects.toThrow("invalid_model_path");
      expect(store.embed).not.toHaveBeenCalled();
    });

  it("rejects an invalid absolute embedding artifact before embedding", async () => {
    const store = fakeStore();
    const invalidArtifact = new Error("model SHA-256 mismatch");
    verifyModelFile.mockRejectedValueOnce(invalidArtifact);

    await expect(indexKnowledge(store as never, "personal", false, "/models/embed.gguf"))
      .rejects.toBe(invalidArtifact);
    expect(store.embed).not.toHaveBeenCalled();
  });

  it("updates and embeds both collections for all scope", async () => {
    const store = fakeStore();
    store.update.mockResolvedValue({});
    store.embed.mockResolvedValue({});

    await indexKnowledge(store as never, "all", false, "/models/embed.gguf");

    expect(store.update).toHaveBeenCalledWith(undefined);
    expect(store.embed).toHaveBeenNthCalledWith(1, {
      collection: "personal",
      force: false,
      model: "/models/embed.gguf",
    });
    expect(store.embed).toHaveBeenNthCalledWith(2, {
      collection: "wooto",
      force: false,
      model: "/models/embed.gguf",
    });
  });

  it("retrieves only canonical qmd references", async () => {
    const store = fakeStore();
    store.get.mockResolvedValue({
      filepath: "qmd://wooto/배포 절차.md",
      title: "배포 절차",
    });
    store.getDocumentBody.mockResolvedValue("첫 줄\n둘째 줄");

    await expect(getKnowledge(store as never, "qmd://wooto/배포 절차.md", 2, 1)).resolves.toEqual({
      uri: "qmd://wooto/%EB%B0%B0%ED%8F%AC%20%EC%A0%88%EC%B0%A8.md",
      title: "배포 절차",
      body: "첫 줄\n둘째 줄",
    });
    expect(store.get).toHaveBeenCalledWith("qmd://wooto/배포 절차.md");
    expect(store.getDocumentBody).toHaveBeenCalledWith(
      "qmd://wooto/배포 절차.md",
      { fromLine: 2, maxLines: 1 },
    );
  });

  it("rejects a fuzzy qmd get result with a different filepath", async () => {
    const store = fakeStore();
    store.get.mockResolvedValue({
      filepath: "qmd://personal/100X_plan.md",
      title: "다른 문서",
    });

    await expect(getKnowledge(store as never, "qmd://personal/100%25_plan.md"))
      .rejects.toThrow("not_found");
    expect(store.getDocumentBody).not.toHaveBeenCalled();
  });

  it.each(["personal/배포.md", "#abc123", "qmd://shared/배포.md"])
    ("rejects non-canonical retrieval ref %s", async (ref) => {
      const store = fakeStore();

      await expect(getKnowledge(store as never, ref)).rejects.toThrow("invalid_ref");
      expect(store.get).not.toHaveBeenCalled();
    });

  it.each([
    "qmd://personal/%2F.md",
    "qmd://personal/%2E%2E",
    "qmd://personal/bad%",
    "qmd://personal/a//b",
    "qmd://personal/..\\secret.md",
    "qmd://personal/%2E%2E%5Csecret.md",
  ])("rejects unsafe canonical escape %s", async (ref) => {
    const store = fakeStore();

    await expect(getKnowledge(store as never, ref)).rejects.toThrow("invalid_ref");
    expect(store.get).not.toHaveBeenCalled();
  });

  it("returns qmd index status and health together", async () => {
    const store = fakeStore();
    const status = { totalDocuments: 2, needsEmbedding: 0, hasVectorIndex: true, collections: [] };
    const health = { needsEmbedding: 0, totalDocs: 2, daysStale: null };
    store.getStatus.mockResolvedValue(status);
    store.getIndexHealth.mockResolvedValue(health);

    await expect(getKnowledgeStatus(store as never)).resolves.toEqual({ status, health });
  });

  it("opens index stores with only the two markdown collections and disabled extra models", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-qmd-"));
    const resolved = paths(root);
    const store = fakeStore();
    createStore.mockResolvedValue(store);
    await mkdir(join(root, "checkout", "personal"), { recursive: true });
    await mkdir(join(root, "checkout", "wooto"), { recursive: true });

    await expect(openIndexStore(join(root, "checkout"), resolved)).resolves.toBe(store);

    await expect(access(join(root, "cache", "indexes"))).resolves.toBeUndefined();
    expect(verifyModelFile).toHaveBeenCalledWith(resolved.modelFile, expect.any(Object));
    expect(createStore).toHaveBeenCalledWith({
      dbPath: resolved.indexFile,
      config: {
        collections: {
          personal: {
            path: join(root, "checkout", "personal"),
            pattern: "**/*.md",
            includeByDefault: true,
          },
          wooto: {
            path: join(root, "checkout", "wooto"),
            pattern: "**/*.md",
            includeByDefault: true,
          },
        },
        models: {
          embed: resolved.modelFile,
          generate: resolved.disabledGenerateModel,
          rerank: resolved.disabledRerankModel,
        },
      },
    });
    expect(process.env.QMD_EMBED_MODEL).toBe(resolved.modelFile);
    expect(process.env.QMD_GENERATE_MODEL).toBe(resolved.disabledGenerateModel);
    expect(process.env.QMD_RERANK_MODEL).toBe(resolved.disabledRerankModel);
  });

  it("rejects a collection root symlink before opening the index store", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-qmd-"));
    const checkoutPath = join(root, "checkout");
    const personalTarget = join(root, "personal-target");
    await mkdir(personalTarget, { recursive: true });
    await mkdir(join(checkoutPath, "wooto"), { recursive: true });
    await symlink(personalTarget, join(checkoutPath, "personal"));

    await expect(openIndexStore(checkoutPath, paths(root)))
      .rejects.toThrow("required path is not a directory");
    expect(createStore).not.toHaveBeenCalled();
  });

  it("opens search stores without a config file", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-qmd-"));
    const resolved = paths(root);
    const store = fakeStore();
    createStore.mockResolvedValue(store);

    await expect(openSearchStore(resolved)).resolves.toBe(store);

    expect(createStore).toHaveBeenCalledWith({ dbPath: resolved.indexFile });
  });

  it("rejects a relative embedding model path before opening qmd", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-qmd-"));
    const resolved = { ...paths(root), modelFile: "models/embed.gguf" };

    await expect(openSearchStore(resolved)).rejects.toThrow("invalid_model_path");
    expect(createStore).not.toHaveBeenCalled();
  });
});
