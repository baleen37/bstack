import { execFile as execFileCallback } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { access, copyFile, mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { delimiter, dirname, join, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { promisify } from "node:util";
import { afterEach, describe, expect, it, vi } from "vitest";
import { bootstrapRuntimeDependencies } from "../src/runtime-bootstrap.js";

const runtimeDependencies = [
  "@modelcontextprotocol/sdk",
  "@tobilu/qmd",
  "zod",
];
const roots: string[] = [];
const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const execFile = promisify(execFileCallback);

async function runtimeRoot(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "knowledge-base-runtime-"));
  roots.push(root);
  await Promise.all([
    copyFile(join(packageRoot, "package.json"), join(root, "package.json")),
    copyFile(join(packageRoot, "package-lock.json"), join(root, "package-lock.json")),
  ]);
  return root;
}

async function createDependencyDirectories(root: string): Promise<void> {
  await Promise.all(runtimeDependencies.map(async (dependency) => {
    const directory = join(root, "node_modules", dependency);
    await mkdir(directory, { recursive: true });
    await writeFile(join(directory, "package.json"), "{}\n");
  }));
}

function successfulRunner() {
  return vi.fn(asyncRunner);
}

function asyncRunner(
  _command: string,
  _args: readonly string[],
  options: { cwd: string },
): { status: number; stderr: string } {
  createDependencyDirectoriesSync(options.cwd);
  return { status: 0, stderr: "" };
}

function createDependencyDirectoriesSync(root: string): void {
  for (const dependency of runtimeDependencies) {
    const directory = join(root, "node_modules", dependency);
    mkdirSync(directory, { recursive: true });
    writeFileSync(join(directory, "package.json"), "{}\n");
  }
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

afterEach(async () => {
  vi.restoreAllMocks();
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

describe("knowledge-base runtime bootstrap", () => {
  it("does not treat dependency directories without a success marker as ready", async () => {
    const root = await runtimeRoot();
    await createDependencyDirectories(root);
    const runner = successfulRunner();

    bootstrapRuntimeDependencies(root, runner as never);

    expect(runner).toHaveBeenCalledOnce();
  });

  it("skips npm when the successful install marker matches the lockfile", async () => {
    const root = await runtimeRoot();
    bootstrapRuntimeDependencies(root, successfulRunner() as never);
    const runner = vi.fn();

    bootstrapRuntimeDependencies(root, runner as never);

    expect(runner).not.toHaveBeenCalled();
  });

  it("reinstalls when the package-lock fingerprint changes", async () => {
    const root = await runtimeRoot();
    bootstrapRuntimeDependencies(root, successfulRunner() as never);
    const lockPath = join(root, "package-lock.json");
    await writeFile(lockPath, `${await readFile(lockPath, "utf8")}\n`);
    const runner = successfulRunner();

    bootstrapRuntimeDependencies(root, runner as never);

    expect(runner).toHaveBeenCalledOnce();
  });

  it("runs exact production npm ci in plugin-internal staging with isolated caches", async () => {
    const root = await runtimeRoot();
    let stagedPackage = "";
    let stagedLock = "";
    const runner = vi.fn((
      _command: string,
      _args: readonly string[],
      options: { cwd: string },
    ) => {
      stagedPackage = readFileSync(join(options.cwd, "package.json"), "utf8");
      stagedLock = readFileSync(join(options.cwd, "package-lock.json"), "utf8");
      createDependencyDirectoriesSync(options.cwd);
      return { status: 0, stderr: "" };
    });

    bootstrapRuntimeDependencies(root, runner as never);

    expect(runner).toHaveBeenCalledOnce();
    const [command, args, options] = runner.mock.calls[0]!;
    expect(command).toBe(process.platform === "win32" ? "npm.cmd" : "npm");
    expect(args).toEqual(["ci", "--omit=dev", "--legacy-peer-deps", "--no-audit", "--no-fund"]);
    expect(options).toEqual(expect.objectContaining({
      encoding: "utf8",
      stdio: ["ignore", "ignore", "pipe"],
      env: expect.objectContaining({
        npm_config_dangerously_allow_all_scripts: "true",
        npm_config_ignore_scripts: "false",
      }),
    }));

    const stagingRoot = options.cwd;
    expect(stagingRoot).not.toBe(root);
    expect(resolve(stagingRoot).startsWith(`${resolve(root)}${sep}`)).toBe(true);
    expect(stagedPackage).toBe(await readFile(join(root, "package.json"), "utf8"));
    expect(stagedLock).toBe(await readFile(join(root, "package-lock.json"), "utf8"));

    const environment = options.env as NodeJS.ProcessEnv;
    for (const key of [
      "npm_config_cache",
      "npm_config_devdir",
      "XDG_CACHE_HOME",
      "XDG_CONFIG_HOME",
      "XDG_DATA_HOME",
      "XDG_STATE_HOME",
      "HOME",
      "USERPROFILE",
      "TMPDIR",
      "TMP",
      "TEMP",
      "CCACHE_DIR",
      "NODE_LLAMA_CPP_XPACKS_STORE_FOLDER",
      "NODE_LLAMA_CPP_XPACKS_CACHE_FOLDER",
    ]) {
      expect(environment[key], key).toBeTypeOf("string");
      expect(resolve(environment[key]!).startsWith(`${resolve(root)}${sep}`), key).toBe(true);
    }
    expect(environment.npm_config_workspace).toBeUndefined();
    expect(environment.npm_config_workspaces).toBeUndefined();

    expect(await pathExists(join(root, "node_modules", "@tobilu", "qmd"))).toBe(true);
    expect(await pathExists(stagingRoot)).toBe(false);
  });

  it("cleans a failed staging install and retries instead of trusting stale directories", async () => {
    const root = await runtimeRoot();
    const write = vi.spyOn(process.stderr, "write").mockImplementation(() => true);
    const stagingRoots: string[] = [];
    const runner = vi.fn((
      _command: string,
      _args: readonly string[],
      options: { cwd: string },
    ) => {
      stagingRoots.push(options.cwd);
      createDependencyDirectoriesSync(options.cwd);
      return runner.mock.calls.length === 1
        ? { status: 42, stderr: "native install failed\n" }
        : { status: 0, stderr: "" };
    });

    expect(() => bootstrapRuntimeDependencies(root, runner as never))
      .toThrow("Failed to install knowledge-base runtime dependencies.");
    expect(() => bootstrapRuntimeDependencies(root, runner as never)).not.toThrow();

    expect(runner).toHaveBeenCalledTimes(2);
    expect(write).toHaveBeenCalledWith("native install failed\n");
    for (const stagingRoot of stagingRoots) {
      expect(await pathExists(stagingRoot)).toBe(false);
    }
    expect(await pathExists(join(root, ".knowledge-base-runtime", "bootstrap.lock"))).toBe(false);
  });

  it.skipIf(process.platform === "win32")(
    "serializes concurrent processes so only one npm install runs",
    async () => {
      const root = await runtimeRoot();
      const fakeBin = join(root, "fake-bin");
      const counterPath = join(root, "npm-invocations");
      const npmPath = join(fakeBin, "npm");
      await mkdir(fakeBin);
      await writeFile(npmPath, `#!${process.execPath}
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
appendFileSync(process.env.TEST_COUNTER, "npm\\n");
Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 350);
for (const dependency of ${JSON.stringify(runtimeDependencies)}) {
  const directory = join(process.cwd(), "node_modules", dependency);
  mkdirSync(directory, { recursive: true });
  writeFileSync(join(directory, "package.json"), "{}\\n");
}
`, { mode: 0o755 });
      const runtimeModule = pathToFileURL(join(packageRoot, "dist", "runtime-bootstrap.js")).href;
      const childScript = `
import { bootstrapRuntimeDependencies } from ${JSON.stringify(runtimeModule)};
bootstrapRuntimeDependencies(process.argv[1]);
`;
      const environment = {
        ...process.env,
        PATH: `${fakeBin}${delimiter}${process.env.PATH ?? ""}`,
        TEST_COUNTER: counterPath,
      };

      await Promise.all([
        execFile(process.execPath, ["--input-type=module", "-e", childScript, root], {
          env: environment,
          timeout: 10_000,
        }),
        execFile(process.execPath, ["--input-type=module", "-e", childScript, root], {
          env: environment,
          timeout: 10_000,
        }),
      ]);

      expect((await readFile(counterPath, "utf8")).trim().split("\n")).toEqual(["npm"]);
    },
    15_000,
  );

  it("preserves npm stderr and fails when bootstrap cannot complete", async () => {
    const root = await runtimeRoot();
    const write = vi.spyOn(process.stderr, "write").mockImplementation(() => true);
    const runner = vi.fn(() => ({ status: 42, stderr: "native install failed\n" }));

    expect(() => bootstrapRuntimeDependencies(root, runner as never))
      .toThrow("Failed to install knowledge-base runtime dependencies.");
    expect(write).toHaveBeenCalledWith("native install failed\n");
  });
});
