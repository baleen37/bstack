import { join } from "node:path";
import { isRepository, type ResolvedPaths } from "./types.js";

export function resolvePaths(
  env: NodeJS.ProcessEnv,
  platform: NodeJS.Platform,
  home: string,
  repository: string,
): ResolvedPaths {
  if (!isRepository(repository)) {
    throw new Error("repository must use owner/name form");
  }
  const [owner, name] = repository.split("/") as [string, string];

  const configBase = platform === "darwin"
    ? join(home, "Library", "Application Support")
    : platform === "win32"
      ? env.APPDATA ?? join(home, "AppData", "Roaming")
      : env.XDG_CONFIG_HOME ?? join(home, ".config");
  const dataBase = platform === "darwin"
    ? join(home, "Library", "Application Support")
    : platform === "win32"
      ? env.LOCALAPPDATA ?? join(home, "AppData", "Local")
      : env.XDG_DATA_HOME ?? join(home, ".local", "share");
  const cacheBase = platform === "darwin"
    ? join(home, "Library", "Caches")
    : platform === "win32"
      ? env.LOCALAPPDATA ?? join(home, "AppData", "Local")
      : env.XDG_CACHE_HOME ?? join(home, ".cache");
  const configDir = env.KNOWLEDGE_BASE_CONFIG_DIR
    ?? join(configBase, "knowledge-base");
  const dataDir = env.KNOWLEDGE_BASE_DATA_DIR
    ?? join(dataBase, "knowledge-base");
  const cacheDir = env.KNOWLEDGE_BASE_CACHE_DIR
    ?? join(cacheBase, "knowledge-base");
  const repoKey = join(owner, name);
  const modelFile = join(cacheDir, "models", "qwen3-embedding-0.6b-q4-k-m.gguf");

  return {
    configDir,
    configFile: join(configDir, "config.json"),
    dataDir,
    cacheDir,
    repositoryDir: join(dataDir, "repositories", repoKey),
    indexFile: join(cacheDir, "indexes", owner, `${name}.sqlite`),
    modelFile,
    disabledGenerateModel: join(cacheDir, "disabled", "generate.gguf"),
    disabledRerankModel: join(cacheDir, "disabled", "rerank.gguf"),
  };
}
