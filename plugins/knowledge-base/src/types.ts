export const SCOPES = ["personal", "wooto", "all"] as const;
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
  run(
    command: string,
    args: readonly string[],
    options?: { cwd?: string },
  ): Promise<RunResult>;
}

export function isRepository(value: string): boolean {
  const match = /^([A-Za-z0-9_.-]+)\/([A-Za-z0-9_.-]+)$/.exec(value);
  if (match === null) {
    return false;
  }
  const [, owner, name] = match;
  return owner !== "." && owner !== ".." && name !== "." && name !== "..";
}

export function isScope(value: string): value is Scope {
  return (SCOPES as readonly string[]).includes(value);
}
