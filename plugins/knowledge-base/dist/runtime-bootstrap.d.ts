import { spawnSync } from "node:child_process";
export declare function hasRuntimeDependencies(pluginRoot: string): boolean;
export declare function bootstrapRuntimeDependencies(pluginRoot: string, runner?: typeof spawnSync): void;
