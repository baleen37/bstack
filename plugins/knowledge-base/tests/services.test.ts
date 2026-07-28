import { beforeEach, describe, expect, it, vi } from "vitest";
import type { AppConfig, ResolvedPaths } from "../src/types.js";

const loadConfig = vi.hoisted(() => vi.fn());
const saveConfig = vi.hoisted(() => vi.fn());
const ensureModel = vi.hoisted(() => vi.fn());
const resolvePaths = vi.hoisted(() => vi.fn());
const setupRepository = vi.hoisted(() => vi.fn());
const syncRepository = vi.hoisted(() => vi.fn());
const openIndexStore = vi.hoisted(() => vi.fn());
const openSearchStore = vi.hoisted(() => vi.fn());
const indexKnowledge = vi.hoisted(() => vi.fn());
const searchKnowledge = vi.hoisted(() => vi.fn());
const getKnowledge = vi.hoisted(() => vi.fn());
const getKnowledgeStatus = vi.hoisted(() => vi.fn());

vi.mock("../src/config.js", () => ({ loadConfig, saveConfig }));
vi.mock("../src/model.js", () => ({ ensureModel }));
vi.mock("../src/paths.js", () => ({ resolvePaths }));
vi.mock("../src/repository.js", () => ({ setupRepository, syncRepository }));
vi.mock("../src/qmd.js", () => ({
  openIndexStore,
  openSearchStore,
  indexKnowledge,
  searchKnowledge,
  getKnowledge,
  getKnowledgeStatus,
}));

import { createServices } from "../src/services.js";

const paths: ResolvedPaths = {
  configDir: "/config",
  configFile: "/config/config.json",
  dataDir: "/data",
  cacheDir: "/cache",
  repositoryDir: "/data/repositories/owner/repo",
  indexFile: "/cache/index.sqlite",
  modelFile: "/cache/model.gguf",
  disabledGenerateModel: "/cache/disabled/generate.gguf",
  disabledRerankModel: "/cache/disabled/rerank.gguf",
};

const config: AppConfig = {
  repository: "owner/repo",
  checkoutPath: "/checkout",
  defaultScope: "all",
};

function fakeStore(close = vi.fn().mockResolvedValue(undefined)) {
  return { close };
}

beforeEach(() => {
  vi.resetAllMocks();
  resolvePaths.mockReturnValue(paths);
  loadConfig.mockResolvedValue(config);
  saveConfig.mockResolvedValue(undefined);
  ensureModel.mockResolvedValue(paths.modelFile);
  setupRepository.mockResolvedValue(undefined);
  syncRepository.mockResolvedValue(undefined);
  indexKnowledge.mockResolvedValue({});
  searchKnowledge.mockResolvedValue([]);
  getKnowledge.mockResolvedValue({});
  getKnowledgeStatus.mockResolvedValue({});
});

describe("knowledge-base service facade", () => {
  it("saves setup config only after repository and model setup succeed", async () => {
    const calls: string[] = [];
    setupRepository.mockImplementation(async () => { calls.push("repository"); });
    ensureModel.mockImplementation(async () => { calls.push("model"); });
    saveConfig.mockImplementation(async () => { calls.push("config"); });

    await expect(createServices().setup({ repository: "owner/repo", path: "/checkout" }))
      .resolves.toEqual(config);

    expect(calls).toEqual(["repository", "model", "config"]);
    expect(saveConfig).toHaveBeenCalledWith(paths.configFile, config);
  });

  it("does not save config when repository setup fails", async () => {
    const failure = new Error("repository failed");
    setupRepository.mockRejectedValue(failure);

    await expect(createServices().setup({ repository: "owner/repo" })).rejects.toBe(failure);

    expect(ensureModel).not.toHaveBeenCalled();
    expect(saveConfig).not.toHaveBeenCalled();
  });

  it("does not save config when model setup fails", async () => {
    const failure = new Error("model failed");
    ensureModel.mockRejectedValue(failure);

    await expect(createServices().setup({ repository: "owner/repo" })).rejects.toBe(failure);

    expect(setupRepository).toHaveBeenCalledOnce();
    expect(saveConfig).not.toHaveBeenCalled();
  });

  it.each([
    ["index", openIndexStore, indexKnowledge, () => createServices().index("all", false)],
    ["search", openSearchStore, searchKnowledge, () => createServices().search("query", "all", 10)],
    ["get", openSearchStore, getKnowledge, () => createServices().get("qmd://personal/file.md")],
    ["status", openSearchStore, getKnowledgeStatus, () => createServices().status()],
  ])("closes the store when %s fails", async (_name, openStore, operation, invoke) => {
    const failure = new Error("operation failed");
    const close = vi.fn().mockResolvedValue(undefined);
    openStore.mockResolvedValue(fakeStore(close));
    operation.mockRejectedValue(failure);

    await expect(invoke()).rejects.toBe(failure);

    expect(close).toHaveBeenCalledOnce();
  });

  it("preserves operation and close errors together", async () => {
    const operationFailure = new Error("index failed");
    const closeFailure = new Error("close failed");
    openIndexStore.mockResolvedValue(fakeStore(vi.fn().mockRejectedValue(closeFailure)));
    indexKnowledge.mockRejectedValue(operationFailure);

    await expect(createServices().index("all", false)).rejects.toSatisfy((error: unknown) => {
      return error instanceof AggregateError
        && error.errors.includes(operationFailure)
        && error.errors.includes(closeFailure);
    });
  });
});
