#!/usr/bin/env node
import { type KnowledgeBaseServices } from "./services.js";
export interface CliIo {
    stdout(text: string): void;
    stderr(text: string): void;
}
export declare function runCli(argv: readonly string[], services: KnowledgeBaseServices, io: CliIo): Promise<number>;
export declare function assertSupportedNodeVersion(version?: string): void;
export declare function main(argv?: readonly string[], services?: KnowledgeBaseServices, io?: CliIo): Promise<number>;
