import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { KnowledgeBaseServices } from "./services.js";
type ReadServices = Pick<KnowledgeBaseServices, "search" | "get" | "status">;
export declare function createKnowledgeBaseMcpServer(services: ReadServices): McpServer;
export declare function startMcpServer(services: ReadServices): Promise<void>;
export {};
