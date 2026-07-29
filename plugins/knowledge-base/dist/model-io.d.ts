import { mkdir, open, rename } from "node:fs/promises";
export { mkdir, open, rename };
export declare function removeTemporary(file: string): Promise<void>;
export declare function syncDirectory(directory: string): Promise<void>;
