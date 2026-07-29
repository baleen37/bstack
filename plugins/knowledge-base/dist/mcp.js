import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { PACKAGE_VERSION } from "./package-version.js";
const searchInput = z.object({
    query: z.string().min(1),
    scope: z.enum(["personal", "wooto", "all"]).default("all"),
    limit: z.number().int().min(1).max(50).default(10),
}).strict();
const getInput = z.object({
    ref: z.string().min(1),
    fromLine: z.number().int().min(1).optional(),
    maxLines: z.number().int().min(1).max(1000).optional(),
}).strict();
const statusInput = z.object({}).strict();
const readOnlyAnnotations = {
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
};
export function createKnowledgeBaseMcpServer(services) {
    const server = new McpServer({
        name: "knowledge-base",
        version: PACKAGE_VERSION,
    });
    server.registerTool("get", {
        description: "Retrieve a knowledge-base document by its canonical qmd reference.",
        inputSchema: getInput,
        annotations: readOnlyAnnotations,
    }, async ({ ref, fromLine, maxLines }) => toolResult(() => services.get(ref, fromLine, maxLines)));
    server.registerTool("search", {
        description: "Search the local knowledge-base index.",
        inputSchema: searchInput,
        annotations: readOnlyAnnotations,
    }, async ({ query, scope, limit }) => toolResult(() => services.search(query, scope, limit)));
    server.registerTool("status", {
        description: "Report local knowledge-base index status.",
        inputSchema: statusInput,
        annotations: readOnlyAnnotations,
    }, async () => toolResult(() => services.status()));
    return server;
}
export async function startMcpServer(services) {
    const server = createKnowledgeBaseMcpServer(services);
    const transport = new StdioServerTransport();
    await server.connect(transport);
}
async function toolResult(operation) {
    try {
        const result = await operation();
        return {
            content: [{ type: "text", text: JSON.stringify(result) }],
            structuredContent: { result },
        };
    }
    catch (error) {
        return {
            content: [{ type: "text", text: message(error) }],
            isError: true,
        };
    }
}
function message(error) {
    return error instanceof Error ? error.message : String(error);
}
//# sourceMappingURL=mcp.js.map