import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import {
  copyFileSync,
  existsSync,
  linkSync,
  mkdirSync,
  readFileSync,
  renameSync,
  rmSync,
  unlinkSync,
  writeFileSync,
} from "node:fs";
import { resolve } from "node:path";

const RUNTIME_DEPENDENCIES = [
  "@modelcontextprotocol/sdk",
  "@tobilu/qmd",
  "zod",
] as const;
const RUNTIME_STATE_DIRECTORY = ".knowledge-base-runtime";
const READY_MARKER = "ready.json";
const BOOTSTRAP_LOCK = "bootstrap.lock";
const LOCK_TIMEOUT_MS = 15 * 60_000;
const LOCK_POLL_MS = 100;
const npmArguments = ["ci", "--omit=dev", "--legacy-peer-deps", "--no-audit", "--no-fund"] as const;

interface ReadyMarker {
  lockfileSha256: string;
}

export function hasRuntimeDependencies(pluginRoot: string): boolean {
  try {
    const marker = JSON.parse(
      readFileSync(resolve(pluginRoot, RUNTIME_STATE_DIRECTORY, READY_MARKER), "utf8"),
    ) as Partial<ReadyMarker>;
    return marker.lockfileSha256 === lockfileFingerprint(pluginRoot)
      && RUNTIME_DEPENDENCIES.every((dependency) =>
        existsSync(resolve(pluginRoot, "node_modules", dependency, "package.json"))
      );
  } catch {
    return false;
  }
}

export function bootstrapRuntimeDependencies(
  pluginRoot: string,
  runner: typeof spawnSync = spawnSync,
): void {
  if (hasRuntimeDependencies(pluginRoot)) return;

  withBootstrapLock(pluginRoot, () => {
    if (hasRuntimeDependencies(pluginRoot)) return;
    installRuntimeDependencies(pluginRoot, runner);
  });
}

function installRuntimeDependencies(
  pluginRoot: string,
  runner: typeof spawnSync,
): void {
  const stateRoot = resolve(pluginRoot, RUNTIME_STATE_DIRECTORY);
  const stagingRoot = resolve(stateRoot, `install-${process.pid}-${randomUUID()}`);
  const markerPath = resolve(stateRoot, READY_MARKER);
  mkdirSync(stagingRoot, { recursive: true });
  rmSync(markerPath, { force: true });

  try {
    copyFileSync(resolve(pluginRoot, "package.json"), resolve(stagingRoot, "package.json"));
    copyFileSync(resolve(pluginRoot, "package-lock.json"), resolve(stagingRoot, "package-lock.json"));

    const result = runner(
      process.platform === "win32" ? "npm.cmd" : "npm",
      [...npmArguments],
      {
        cwd: stagingRoot,
        encoding: "utf8",
        env: isolatedBootstrapEnvironment(stateRoot),
        stdio: ["ignore", "ignore", "pipe"],
      },
    );

    if (result.status !== 0 || !hasStagedRuntimeDependencies(stagingRoot)) {
      if (typeof result.stderr === "string" && result.stderr !== "") {
        process.stderr.write(result.stderr);
      }
      throw new Error("Failed to install knowledge-base runtime dependencies.");
    }

    promoteNodeModules(pluginRoot, stateRoot, stagingRoot);
    writeReadyMarker(pluginRoot, stateRoot);
  } finally {
    rmSync(stagingRoot, { recursive: true, force: true });
  }
}

function hasStagedRuntimeDependencies(stagingRoot: string): boolean {
  return RUNTIME_DEPENDENCIES.every((dependency) =>
    existsSync(resolve(stagingRoot, "node_modules", dependency, "package.json"))
  );
}

function promoteNodeModules(
  pluginRoot: string,
  stateRoot: string,
  stagingRoot: string,
): void {
  const installed = resolve(stagingRoot, "node_modules");
  const target = resolve(pluginRoot, "node_modules");
  const backup = resolve(stateRoot, `node_modules-backup-${process.pid}-${randomUUID()}`);
  const hadPreviousInstall = existsSync(target);

  if (hadPreviousInstall) renameSync(target, backup);
  try {
    renameSync(installed, target);
  } catch (error) {
    if (hadPreviousInstall && existsSync(backup)) renameSync(backup, target);
    throw error;
  }
  rmSync(backup, { recursive: true, force: true });
}

function writeReadyMarker(pluginRoot: string, stateRoot: string): void {
  const markerPath = resolve(stateRoot, READY_MARKER);
  const temporaryMarker = resolve(stateRoot, `ready-${process.pid}-${randomUUID()}.tmp`);
  const marker: ReadyMarker = {
    lockfileSha256: lockfileFingerprint(pluginRoot),
  };
  try {
    writeFileSync(temporaryMarker, `${JSON.stringify(marker)}\n`, { flag: "wx" });
    renameSync(temporaryMarker, markerPath);
  } finally {
    rmSync(temporaryMarker, { force: true });
  }
}

function lockfileFingerprint(pluginRoot: string): string {
  return createHash("sha256")
    .update(readFileSync(resolve(pluginRoot, "package-lock.json")))
    .digest("hex");
}

function isolatedBootstrapEnvironment(stateRoot: string): NodeJS.ProcessEnv {
  const environment = { ...process.env };
  const overriddenKeys = new Set([
    "ccache_dir",
    "home",
    "node_llama_cpp_xpacks_cache_folder",
    "node_llama_cpp_xpacks_store_folder",
    "npm_config_cache",
    "npm_config_dangerously_allow_all_scripts",
    "npm_config_devdir",
    "npm_config_ignore_scripts",
    "npm_config_workspace",
    "npm_config_workspaces",
    "temp",
    "tmp",
    "tmpdir",
    "userprofile",
    "xdg_cache_home",
    "xdg_config_home",
    "xdg_data_home",
    "xdg_state_home",
  ]);
  for (const key of Object.keys(environment)) {
    if (overriddenKeys.has(key.toLowerCase())) delete environment[key];
  }

  const cacheRoot = resolve(stateRoot, "cache");
  const homeRoot = resolve(stateRoot, "home");
  const temporaryRoot = resolve(stateRoot, "tmp");
  const directories = {
    ccache: resolve(cacheRoot, "ccache"),
    home: homeRoot,
    llamaCache: resolve(cacheRoot, "node-llama-cpp"),
    llamaStore: resolve(stateRoot, "node-llama-cpp"),
    nodeGyp: resolve(cacheRoot, "node-gyp"),
    npm: resolve(cacheRoot, "npm"),
    temporary: temporaryRoot,
    xdgCache: resolve(cacheRoot, "xdg"),
    xdgConfig: resolve(stateRoot, "xdg", "config"),
    xdgData: resolve(stateRoot, "xdg", "data"),
    xdgState: resolve(stateRoot, "xdg", "state"),
  };
  for (const directory of Object.values(directories)) {
    mkdirSync(directory, { recursive: true });
  }

  return {
    ...environment,
    CCACHE_DIR: directories.ccache,
    HOME: directories.home,
    NODE_LLAMA_CPP_XPACKS_CACHE_FOLDER: directories.llamaCache,
    NODE_LLAMA_CPP_XPACKS_STORE_FOLDER: directories.llamaStore,
    TEMP: directories.temporary,
    TMP: directories.temporary,
    TMPDIR: directories.temporary,
    USERPROFILE: directories.home,
    XDG_CACHE_HOME: directories.xdgCache,
    XDG_CONFIG_HOME: directories.xdgConfig,
    XDG_DATA_HOME: directories.xdgData,
    XDG_STATE_HOME: directories.xdgState,
    npm_config_cache: directories.npm,
    npm_config_dangerously_allow_all_scripts: "true",
    npm_config_devdir: directories.nodeGyp,
    npm_config_ignore_scripts: "false",
  };
}

function withBootstrapLock(pluginRoot: string, operation: () => void): void {
  const stateRoot = resolve(pluginRoot, RUNTIME_STATE_DIRECTORY);
  const lockPath = resolve(stateRoot, BOOTSTRAP_LOCK);
  const ownerPath = resolve(stateRoot, `bootstrap-owner-${process.pid}-${randomUUID()}`);
  const owner = `${JSON.stringify({ pid: process.pid, token: randomUUID() })}\n`;
  mkdirSync(stateRoot, { recursive: true });
  writeFileSync(ownerPath, owner, { flag: "wx" });
  let acquired = false;
  const deadline = Date.now() + LOCK_TIMEOUT_MS;

  try {
    while (!acquired) {
      try {
        linkSync(ownerPath, lockPath);
        acquired = true;
      } catch (error) {
        if (!isAlreadyExists(error)) throw error;
        if (removeAbandonedLock(lockPath)) continue;
        if (Date.now() >= deadline) {
          throw new Error("Timed out waiting for knowledge-base runtime bootstrap.");
        }
        sleep(LOCK_POLL_MS);
      }
    }
    operation();
  } finally {
    if (acquired && readFileIfPresent(lockPath) === owner) {
      unlinkSync(lockPath);
    }
    rmSync(ownerPath, { force: true });
  }
}

function removeAbandonedLock(lockPath: string): boolean {
  const contents = readFileIfPresent(lockPath);
  if (contents === undefined) return true;
  try {
    const { pid } = JSON.parse(contents) as { pid?: unknown };
    if (typeof pid === "number" && Number.isInteger(pid) && pid > 0 && isProcessAlive(pid)) {
      return false;
    }
  } catch {
    // Hard-link lock contents are complete before publication; invalid data is abandoned.
  }
  try {
    unlinkSync(lockPath);
    return true;
  } catch (error) {
    if (isNotFound(error)) return true;
    throw error;
  }
}

function isProcessAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return isPermissionDenied(error);
  }
}

function readFileIfPresent(path: string): string | undefined {
  try {
    return readFileSync(path, "utf8");
  } catch (error) {
    if (isNotFound(error)) return undefined;
    throw error;
  }
}

function sleep(milliseconds: number): void {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, milliseconds);
}

function isAlreadyExists(error: unknown): boolean {
  return hasErrorCode(error, "EEXIST");
}

function isNotFound(error: unknown): boolean {
  return hasErrorCode(error, "ENOENT");
}

function isPermissionDenied(error: unknown): boolean {
  return hasErrorCode(error, "EPERM");
}

function hasErrorCode(error: unknown, code: string): boolean {
  return error instanceof Error && "code" in error && error.code === code;
}
