export declare const SCOPES: readonly ["personal", "wooto", "all"];
export type Scope = (typeof SCOPES)[number];
export interface AppConfig {
    repository: string;
    checkoutPath: string;
    defaultScope: Scope;
}
export interface ResolvedPaths {
    configDir: string;
    configFile: string;
    dataDir: string;
    cacheDir: string;
    repositoryDir: string;
    indexFile: string;
    modelFile: string;
    disabledGenerateModel: string;
    disabledRerankModel: string;
}
export interface RunResult {
    exitCode: number;
    stdout: string;
    stderr: string;
}
export interface CommandRunner {
    run(command: string, args: readonly string[], options?: {
        cwd?: string;
    }): Promise<RunResult>;
}
export declare function isRepository(value: string): boolean;
export declare function isScope(value: string): value is Scope;
