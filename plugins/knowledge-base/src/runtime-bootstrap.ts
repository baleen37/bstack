import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve } from "node:path";

const RUNTIME_DEPENDENCIES = [
  "@modelcontextprotocol/sdk",
  "@tobilu/qmd",
  "zod",
] as const;

export function hasRuntimeDependencies(pluginRoot: string): boolean {
  return RUNTIME_DEPENDENCIES.every((dependency) =>
    existsSync(resolve(pluginRoot, "node_modules", dependency))
  );
}

export function bootstrapRuntimeDependencies(
  pluginRoot: string,
  runner: typeof spawnSync = spawnSync,
): void {
  if (hasRuntimeDependencies(pluginRoot)) return;

  const result = runner(
    process.platform === "win32" ? "npm.cmd" : "npm",
    ["ci", "--omit=dev", "--legacy-peer-deps", "--no-audit", "--no-fund"],
    {
      cwd: pluginRoot,
      encoding: "utf8",
      env: {
        ...process.env,
        npm_config_dangerously_allow_all_scripts: "true",
        npm_config_ignore_scripts: "false",
      },
      stdio: ["ignore", "ignore", "pipe"],
    },
  );

  if (result.status !== 0 || !hasRuntimeDependencies(pluginRoot)) {
    if (typeof result.stderr === "string" && result.stderr !== "") {
      process.stderr.write(result.stderr);
    }
    throw new Error("Failed to install knowledge-base runtime dependencies.");
  }
}
