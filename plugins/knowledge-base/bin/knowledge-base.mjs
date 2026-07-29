#!/usr/bin/env node
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const pluginRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

try {
  const bootstrapUrl = pathToFileURL(
    resolve(pluginRoot, "dist", "runtime-bootstrap.js"),
  ).href;
  const cliUrl = pathToFileURL(resolve(pluginRoot, "dist", "cli.js")).href;
  const { bootstrapRuntimeDependencies } = await import(bootstrapUrl);
  bootstrapRuntimeDependencies(pluginRoot);
  const { main } = await import(cliUrl);
  process.exitCode = await main(process.argv.slice(2));
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}
