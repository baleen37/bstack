import { mkdir } from "node:fs/promises";
import { dirname, isAbsolute, join } from "node:path";
import {
  createStore,
  extractSnippet,
  type EmbedResult,
  type IndexHealthInfo,
  type IndexStatus,
  type QMDStore,
  type UpdateResult,
} from "@tobilu/qmd";
import { MODEL_SPEC, verifyModelFile } from "./model.js";
import type { ResolvedPaths, Scope } from "./types.js";

type KnowledgeCollection = "personal" | "wooto";

export interface KnowledgeSearchResult {
  collection: KnowledgeCollection;
  uri: string;
  docid: string;
  title: string;
  line: number;
  snippet: string;
  score: number;
}

interface CanonicalReference {
  collection: KnowledgeCollection;
  uri: string;
  qmdUri: string;
}

export async function openIndexStore(
  checkoutPath: string,
  paths: ResolvedPaths,
): Promise<QMDStore> {
  await prepareStore(paths);
  return createStore({
    dbPath: paths.indexFile,
    config: {
      collections: {
        personal: {
          path: join(checkoutPath, "personal"),
          pattern: "**/*.md",
          includeByDefault: true,
        },
        wooto: {
          path: join(checkoutPath, "wooto"),
          pattern: "**/*.md",
          includeByDefault: true,
        },
      },
      models: {
        embed: paths.modelFile,
        generate: paths.disabledGenerateModel,
        rerank: paths.disabledRerankModel,
      },
    },
  });
}

export async function openSearchStore(paths: ResolvedPaths): Promise<QMDStore> {
  await prepareStore(paths);
  return createStore({ dbPath: paths.indexFile });
}

export async function indexKnowledge(
  store: QMDStore,
  scope: Scope,
  force: boolean,
  modelPath: string,
): Promise<{ update: UpdateResult; embedded: EmbedResult[] }> {
  const collections = scope === "all" ? undefined : [scope];
  const update = await store.update(collections ? { collections } : undefined);
  const targets: readonly KnowledgeCollection[] = scope === "all"
    ? ["personal", "wooto"]
    : [scope];
  const embedded: EmbedResult[] = [];
  for (const collection of targets) {
    embedded.push(await store.embed({ collection, force, model: modelPath }));
  }
  return { update, embedded };
}

export async function searchKnowledge(
  store: Pick<QMDStore, "search">,
  query: string,
  scope: Scope,
  limit: number,
): Promise<KnowledgeSearchResult[]> {
  if (query.trim() === "") {
    throw new Error("invalid_query");
  }
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) {
    throw new Error("invalid_limit");
  }

  const collections = scope === "all" ? undefined : [scope];
  const results = await store.search({
    queries: [
      { type: "lex", query },
      { type: "vec", query },
    ],
    rerank: false,
    limit,
    ...(collections === undefined ? {} : { collections }),
  });

  return results.map((result) => {
    const ref = normalizeReference(result.file);
    if (ref === undefined) {
      throw new Error("invalid_result_uri");
    }
    const snippet = extractSnippet(
      result.body,
      query,
      500,
      result.bestChunkPos,
      result.bestChunk.length,
    );
    return {
      collection: ref.collection,
      uri: ref.uri,
      docid: result.docid,
      title: result.title,
      line: snippet.line,
      snippet: snippet.snippet,
      score: result.score,
    };
  });
}

export async function getKnowledge(
  store: Pick<QMDStore, "get" | "getDocumentBody">,
  ref: string,
  fromLine?: number,
  maxLines?: number,
): Promise<{ uri: string; title: string; body: string }> {
  const canonical = normalizeReference(ref);
  if (canonical === undefined) {
    throw new Error("invalid_ref");
  }

  const document = await store.get(canonical.qmdUri);
  if ("error" in document) {
    throw new Error(document.error);
  }
  const body = await store.getDocumentBody(canonical.qmdUri, { fromLine, maxLines });
  if (body === null) {
    throw new Error("not_found");
  }
  return { uri: canonical.uri, title: document.title, body };
}

export async function getKnowledgeStatus(
  store: Pick<QMDStore, "getStatus" | "getIndexHealth">,
): Promise<{ status: IndexStatus; health: IndexHealthInfo }> {
  const [status, health] = await Promise.all([store.getStatus(), store.getIndexHealth()]);
  return { status, health };
}

async function prepareStore(paths: ResolvedPaths): Promise<void> {
  if (!isAbsolute(paths.modelFile)) {
    throw new Error("invalid_model_path");
  }
  await verifyModelFile(paths.modelFile, MODEL_SPEC);
  await mkdir(dirname(paths.indexFile), { recursive: true, mode: 0o700 });
  process.env.QMD_EMBED_MODEL = paths.modelFile;
  process.env.QMD_GENERATE_MODEL = paths.disabledGenerateModel;
  process.env.QMD_RERANK_MODEL = paths.disabledRerankModel;
}

function normalizeReference(ref: string): CanonicalReference | undefined {
  const match = /^qmd:\/\/(personal|wooto)\/(.+)$/.exec(ref);
  if (match === null) {
    return undefined;
  }
  const collection = match[1] as KnowledgeCollection;
  const path = match[2];
  if (path === undefined) {
    return undefined;
  }
  const segments = path.split("/");
  const decoded: string[] = [];
  for (const segment of segments) {
    try {
      const value = decodeURIComponent(segment);
      if (value === "" || value === "." || value === ".." || value.includes("/")) {
        return undefined;
      }
      decoded.push(value);
    } catch {
      return undefined;
    }
  }
  return {
    collection,
    uri: `qmd://${collection}/${decoded.map(encodeURIComponent).join("/")}`,
    qmdUri: `qmd://${collection}/${decoded.join("/")}`,
  };
}
