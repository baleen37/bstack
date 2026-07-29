import { homedir } from "node:os";
import { isAbsolute } from "node:path";
import { loadConfig, saveConfig } from "./config.js";
import { startMcpServer } from "./mcp.js";
import { ensureModel } from "./model.js";
import { resolvePaths } from "./paths.js";
import { commandRunner } from "./process.js";
import { getKnowledge, getKnowledgeStatus, indexKnowledge, openIndexStore, openSearchStore, searchKnowledge, } from "./qmd.js";
import { setupRepository, syncRepository } from "./repository.js";
const CONFIG_PATH_REPOSITORY = "knowledge-base/config";
export function createServices() {
    return {
        async setup(input) {
            const paths = resolvePaths(process.env, process.platform, homedir(), input.repository);
            if (input.path !== undefined && !isAbsolute(input.path)) {
                throw new Error("--path must be an absolute path");
            }
            const checkoutPath = input.path ?? paths.repositoryDir;
            await setupRepository(input.repository, checkoutPath, commandRunner);
            await ensureModel(paths.modelFile);
            const config = {
                repository: input.repository,
                checkoutPath,
                defaultScope: "all",
            };
            await saveConfig(paths.configFile, config);
            return config;
        },
        async pull() {
            const { config } = await loadConfigured();
            await syncRepository(config.checkoutPath, commandRunner);
        },
        async index(scope, force) {
            const { config, paths } = await loadConfigured();
            return useStore(openIndexStore(config.checkoutPath, paths), (store) => indexKnowledge(store, scope, force, paths.modelFile));
        },
        async search(query, scope, limit) {
            const { paths } = await loadConfigured();
            return useStore(openSearchStore(paths), (store) => searchKnowledge(store, query, scope, limit));
        },
        async get(ref, fromLine, maxLines) {
            const { paths } = await loadConfigured();
            return useStore(openSearchStore(paths), (store) => getKnowledge(store, ref, fromLine, maxLines));
        },
        async status() {
            const { paths } = await loadConfigured();
            return useStore(openSearchStore(paths), (store) => getKnowledgeStatus(store));
        },
        async startMcp() {
            await startMcpServer(this);
        },
    };
}
async function useStore(openStore, operation) {
    const store = await openStore;
    let operationError;
    let operationFailed = false;
    try {
        return await operation(store);
    }
    catch (error) {
        operationFailed = true;
        operationError = error;
        throw error;
    }
    finally {
        try {
            await store.close();
        }
        catch (closeError) {
            if (operationFailed) {
                throw new AggregateError([operationError, closeError], "knowledge-base operation and store close both failed");
            }
            throw closeError;
        }
    }
}
async function loadConfigured() {
    const configPaths = resolvePaths(process.env, process.platform, homedir(), CONFIG_PATH_REPOSITORY);
    const config = await loadConfig(configPaths.configFile);
    return {
        config,
        paths: resolvePaths(process.env, process.platform, homedir(), config.repository),
    };
}
//# sourceMappingURL=services.js.map