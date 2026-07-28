import { mkdir, open, readFile, rename, rm } from "node:fs/promises";
import { dirname } from "node:path";
import { z } from "zod";
import type { AppConfig } from "./types.js";

const configSchema = z.object({
  repository: z.string().regex(/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/),
  checkoutPath: z.string().min(1),
  defaultScope: z.enum(["personal", "wooto", "all"]),
}).strict();

export async function loadConfig(file: string): Promise<AppConfig> {
  return configSchema.parse(JSON.parse(await readFile(file, "utf8")));
}

export async function saveConfig(file: string, config: AppConfig): Promise<void> {
  const value = configSchema.parse(config);
  await mkdir(dirname(file), { recursive: true, mode: 0o700 });
  const temporary = `${file}.${process.pid}.tmp`;
  const handle = await open(temporary, "wx", 0o600);
  try {
    await handle.writeFile(`${JSON.stringify(value, null, 2)}\n`);
    await handle.sync();
    await handle.close();
    await rename(temporary, file);
  } catch (error) {
    await handle.close().catch(() => undefined);
    await rm(temporary, { force: true });
    throw error;
  }
}
