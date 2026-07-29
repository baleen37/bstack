import { type EmbedResult, type IndexHealthInfo, type IndexStatus, type QMDStore, type UpdateResult } from "@tobilu/qmd";
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
export declare function openIndexStore(checkoutPath: string, paths: ResolvedPaths): Promise<QMDStore>;
export declare function openSearchStore(paths: ResolvedPaths): Promise<QMDStore>;
export declare function indexKnowledge(store: QMDStore, scope: Scope, force: boolean, modelPath: string): Promise<{
    update: UpdateResult;
    embedded: EmbedResult[];
}>;
export declare function searchKnowledge(store: Pick<QMDStore, "search">, query: string, scope: Scope, limit: number): Promise<KnowledgeSearchResult[]>;
export declare function getKnowledge(store: Pick<QMDStore, "get" | "getDocumentBody">, ref: string, fromLine?: number, maxLines?: number): Promise<{
    uri: string;
    title: string;
    body: string;
}>;
export declare function getKnowledgeStatus(store: Pick<QMDStore, "getStatus" | "getIndexHealth">): Promise<{
    status: IndexStatus;
    health: IndexHealthInfo;
}>;
export {};
