import { type KnowledgeSearchResult } from "./qmd.js";
import type { AppConfig, Scope } from "./types.js";
export interface KnowledgeBaseServices {
    setup(input: {
        repository: string;
        path?: string;
    }): Promise<AppConfig>;
    pull(): Promise<void>;
    index(scope: Scope, force: boolean): Promise<unknown>;
    search(query: string, scope: Scope, limit: number): Promise<KnowledgeSearchResult[]>;
    get(ref: string, fromLine?: number, maxLines?: number): Promise<unknown>;
    status(): Promise<unknown>;
    startMcp(): Promise<void>;
}
export declare function createServices(): KnowledgeBaseServices;
