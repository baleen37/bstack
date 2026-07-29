import type { CommandRunner } from "./types.js";
export declare function assertRepositoryLayout(checkoutPath: string): Promise<void>;
export declare function setupRepository(repository: string, checkoutPath: string, runner: CommandRunner): Promise<void>;
export declare function syncRepository(checkoutPath: string, runner: CommandRunner): Promise<void>;
