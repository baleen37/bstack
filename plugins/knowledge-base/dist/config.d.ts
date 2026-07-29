import { type AppConfig } from "./types.js";
export declare function loadConfig(file: string): Promise<AppConfig>;
export declare function saveConfig(file: string, config: AppConfig): Promise<void>;
