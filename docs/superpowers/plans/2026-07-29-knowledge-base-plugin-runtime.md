# Knowledge Base Plugin Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the checked-in bstack `knowledge-base` plugin run its CLI and local stdio MCP server without a separate global npm installation.

**Architecture:** Check in deterministic TypeScript build output and a plugin-local launcher. The launcher verifies production dependencies, bootstraps them once with the plugin's own npm lockfile, then invokes the CLI in-process so MCP lifecycle and stdout remain controlled. CI checks generated `dist/` drift, exercises a fresh plugin copy, and keeps release versions synchronized.

**Tech Stack:** Node.js 22+, TypeScript 7, Bun 1.3, npm lockfile v3, Vitest 4, BATS, MCP SDK 1.29.0, qmd 2.5.3.

## Global Constraints

- The default MCP path must use the checked-in plugin runtime; `KNOWLEDGE_BASE_BIN` remains an explicit override only.
- Bootstrap may write only inside the installed plugin directory; knowledge checkout, config, indexes, and models keep their existing user-local paths.
- Bootstrap must run `npm ci --omit=dev --legacy-peer-deps --no-audit --no-fund`; `--legacy-peer-deps` is required because qmd 2.5.3 declares a TypeScript 5 peer while this package uses TypeScript 7.
- Successful bootstrap must write nothing to stdout. Failure diagnostics go to stderr and return non-zero.
- Native dependency install scripts must remain enabled for qmd, better-sqlite3, sqlite-vec, and node-llama-cpp.
- `dist/**` is generated from `src/**`; hand edits to generated files are forbidden.
- The plugin must not add private Markdown, checkout paths, config, SQLite databases, GGUF models, or `node_modules` to Git or npm artifacts.
- The pinned 396,474,496-byte embedding model and existing real-model test are unchanged.
- The CLI is available at the installed plugin's `bin/knowledge-base.mjs`; this change does not modify the user's global `PATH`.

---

## File Structure

- `plugins/knowledge-base/src/cli.ts`: expose the existing CLI lifecycle as `main()`.
- `plugins/knowledge-base/src/runtime-bootstrap.ts`: dependency presence check and one-time npm bootstrap.
- `plugins/knowledge-base/bin/knowledge-base.mjs`: plugin-local executable using only built-ins plus checked-in `dist/`.
- `plugins/knowledge-base/package.json`: local launcher as `bin`, public files, and build scripts.
- `plugins/knowledge-base/package-lock.json`: deterministic npm production bootstrap.
- `plugins/knowledge-base/dist/**`: checked-in generated JavaScript, declarations, and source maps.
- `plugins/knowledge-base/.mcp.json`: local launcher default with explicit override support.
- `.gitignore`: narrow exception for the knowledge-base `dist/`.
- `.github/workflows/ci.yml`: generated-dist drift gate and real plugin runtime smoke.
- `plugins/knowledge-base/tests/runtime-bootstrap.test.ts`: focused bootstrap unit contracts.
- `plugins/knowledge-base/tests/cli-entrypoint.test.ts`: direct and launcher entrypoint behavior.
- `plugins/knowledge-base/tests/plugin-runtime.test.ts`: fresh plugin copy with real npm bootstrap and MCP handshake.
- `tests/knowledge-base/knowledge-base-specific.bats`: manifest, launcher, tracked-dist, and stdio integration contracts.
- `.releaserc.js`: package-lock version synchronization and release asset.
- `tests/github_workflows.bats`: CI and release behavior.
- `plugins/knowledge-base/tests/package.test.ts`: npm tarball public-file allowlist.
- `plugins/knowledge-base/README.md`: plugin-local CLI and first-run behavior.

---

### Task 1: Plugin-local launcher and deterministic runtime bootstrap

**Files:**
- Create: `plugins/knowledge-base/src/runtime-bootstrap.ts`
- Create: `plugins/knowledge-base/bin/knowledge-base.mjs`
- Create: `plugins/knowledge-base/package-lock.json`
- Create: `plugins/knowledge-base/tests/runtime-bootstrap.test.ts`
- Modify: `plugins/knowledge-base/src/cli.ts:268-297`
- Modify: `plugins/knowledge-base/package.json:10-32`
- Modify: `plugins/knowledge-base/tests/cli-entrypoint.test.ts`

**Interfaces:**
- Produces: `main(argv?: readonly string[], services?: KnowledgeBaseServices, io?: CliIo): Promise<number>` in `src/cli.ts`.
- Produces: `hasRuntimeDependencies(pluginRoot: string): boolean` and `bootstrapRuntimeDependencies(pluginRoot: string, runner?: typeof spawnSync): void`.
- Produces: executable `bin/knowledge-base.mjs`, which forwards `process.argv.slice(2)` to `main()`.
- Consumes: exact direct dependencies from `plugins/knowledge-base/package.json`.

- [ ] **Step 1: Write failing CLI-main and bootstrap tests**

Add a `main()` test to `tests/cli-entrypoint.test.ts` using injected services and memory IO:

```ts
it("runs the exported CLI main without requiring the file to be the entrypoint", async () => {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const services = fakeServices();

  await expect(main(["--version"], services, {
    stdout: (text) => stdout.push(text),
    stderr: (text) => stderr.push(text),
  })).resolves.toBe(0);

  expect(stdout).toEqual([`${expectedVersion}\n`]);
  expect(stderr).toEqual([]);
});
```

Create `tests/runtime-bootstrap.test.ts` with three contracts:

```ts
it("skips npm when all direct runtime dependencies exist", async () => {
  const root = await runtimeRoot();
  await createDependencyDirectories(root);
  const runner = vi.fn();

  bootstrapRuntimeDependencies(root, runner as never);

  expect(runner).not.toHaveBeenCalled();
});

it("runs deterministic production npm ci when a dependency is missing", async () => {
  const root = await runtimeRoot();
  const runner = vi.fn(() => {
    createDependencyDirectoriesSync(root);
    return { status: 0, stderr: "" };
  });

  bootstrapRuntimeDependencies(root, runner as never);

  expect(runner).toHaveBeenCalledWith(
    process.platform === "win32" ? "npm.cmd" : "npm",
    ["ci", "--omit=dev", "--legacy-peer-deps", "--no-audit", "--no-fund"],
    expect.objectContaining({
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "ignore", "pipe"],
    }),
  );
});

it("preserves npm stderr and fails when bootstrap cannot complete", async () => {
  const root = await runtimeRoot();
  const write = vi.spyOn(process.stderr, "write").mockImplementation(() => true);
  const runner = vi.fn(() => ({ status: 42, stderr: "native install failed\n" }));

  expect(() => bootstrapRuntimeDependencies(root, runner as never))
    .toThrow("Failed to install knowledge-base runtime dependencies.");
  expect(write).toHaveBeenCalledWith("native install failed\n");
});
```

The test helper must create these exact paths:

```ts
const runtimeDependencies = [
  "@modelcontextprotocol/sdk",
  "@tobilu/qmd",
  "zod",
];
```

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```bash
bun run --cwd plugins/knowledge-base test -- \
  cli-entrypoint.test.ts runtime-bootstrap.test.ts
```

Expected: FAIL because `main`, `runtime-bootstrap.ts`, and its exported functions do not exist.

- [ ] **Step 3: Extract the CLI lifecycle into `main()`**

Replace the bottom entrypoint block in `src/cli.ts` with:

```ts
const processIo: CliIo = {
  stdout: (text) => process.stdout.write(text),
  stderr: (text) => process.stderr.write(text),
};

export async function main(
  argv: readonly string[] = process.argv.slice(2),
  services: KnowledgeBaseServices = createServices(),
  io: CliIo = processIo,
): Promise<number> {
  try {
    assertSupportedNodeVersion();
    return await runCli(argv, services, io);
  } catch (error) {
    io.stderr(`${message(error)}\n`);
    return 1;
  }
}

if (isEntrypoint(process.argv[1])) {
  process.exitCode = await main();
}
```

Keep `runCli()` and the realpath-based symlink entrypoint check unchanged.

- [ ] **Step 4: Implement the bootstrap module**

Create `src/runtime-bootstrap.ts`:

```ts
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
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
```

- [ ] **Step 5: Add the plugin-local launcher**

Create executable `bin/knowledge-base.mjs`:

```js
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
```

Then run:

```bash
chmod +x plugins/knowledge-base/bin/knowledge-base.mjs
```

- [ ] **Step 6: Point package metadata at the launcher and create the lock**

Change `package.json`:

```json
{
  "bin": {
    "knowledge-base": "bin/knowledge-base.mjs"
  },
  "files": [
    "bin/",
    "dist/",
    "README.md",
    "LICENSE"
  ]
}
```

Generate the nested lock:

```bash
cd plugins/knowledge-base
npm install --package-lock-only --ignore-scripts --workspaces=false \
  --legacy-peer-deps --no-audit --no-fund
```

Expected:

```text
package-lock.json lockfileVersion = 3
package-lock.json packages[""].version = package.json version
```

- [ ] **Step 7: Build and run focused GREEN tests**

Run:

```bash
bun run --cwd plugins/knowledge-base build
bun run --cwd plugins/knowledge-base typecheck
bun run --cwd plugins/knowledge-base test -- \
  cli-entrypoint.test.ts runtime-bootstrap.test.ts
plugins/knowledge-base/bin/knowledge-base.mjs --version
```

Expected: all tests PASS and the launcher prints the exact nested package version.

- [ ] **Step 8: Commit Task 1**

```bash
git add \
  plugins/knowledge-base/bin/knowledge-base.mjs \
  plugins/knowledge-base/package.json \
  plugins/knowledge-base/package-lock.json \
  plugins/knowledge-base/src/cli.ts \
  plugins/knowledge-base/src/runtime-bootstrap.ts \
  plugins/knowledge-base/tests/cli-entrypoint.test.ts \
  plugins/knowledge-base/tests/runtime-bootstrap.test.ts
git commit -m "feat(knowledge-base): add plugin-local runtime launcher"
```

---

### Task 2: Tracked build, local MCP default, and drift gate

**Files:**
- Modify: `.gitignore:15-24`
- Modify: `plugins/knowledge-base/.mcp.json`
- Add: `plugins/knowledge-base/dist/**`
- Modify: `tests/knowledge-base/knowledge-base-specific.bats:120-164`
- Modify: `plugins/knowledge-base/tests/package.test.ts`
- Modify: `.github/workflows/ci.yml:46-52`
- Modify: `tests/github_workflows.bats:143-153`

**Interfaces:**
- Consumes: `bin/knowledge-base.mjs` and generated `dist/runtime-bootstrap.js` from Task 1.
- Produces: default MCP command resolving the local launcher through `PLUGIN_ROOT`, `CLAUDE_PLUGIN_ROOT`, or `$PWD`.
- Produces: CI step named `Check knowledge-base build drift`.

- [ ] **Step 1: Write failing tracked-build and MCP manifest tests**

Update the manifest expectation in `knowledge-base-specific.bats`:

```bash
local expected_args='["-lc","exec \"${KNOWLEDGE_BASE_BIN:-${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$PWD}}/bin/knowledge-base.mjs}\" mcp"]'

[ "$(jq -c '.mcpServers["knowledge-base"].args' "$config")" = "$expected_args" ]
[[ "$(jq -r '.mcpServers["knowledge-base"].args[1]' "$config")" == *"/bin/knowledge-base.mjs"* ]]
[[ "$(jq -r '.mcpServers["knowledge-base"].args[1]' "$config")" != *":-knowledge-base}"* ]]
```

Add a tracked-build test:

```bash
@test "knowledge-base ships a reproducible tracked dist" {
  local package_dir="${PROJECT_ROOT}/plugins/knowledge-base"

  git -C "$PROJECT_ROOT" ls-files --error-unmatch \
    plugins/knowledge-base/dist/cli.js >/dev/null
  git -C "$PROJECT_ROOT" ls-files --error-unmatch \
    plugins/knowledge-base/dist/runtime-bootstrap.js >/dev/null

  run bun run --cwd "$package_dir" build
  [ "$status" -eq 0 ]
  run git -C "$PROJECT_ROOT" diff --exit-code -- plugins/knowledge-base/dist
  [ "$status" -eq 0 ]
}
```

Extend `package.test.ts` required paths:

```ts
expect(paths).toEqual(expect.arrayContaining([
  "bin/knowledge-base.mjs",
  "dist/cli.js",
  "dist/runtime-bootstrap.js",
  "README.md",
  "LICENSE",
  "package.json",
]));
```

Add a workflow assertion:

```bash
drift_command=$(yaml_get "$CI_WORKFLOW" \
  '.jobs.test.steps[] | select(.name == "Check knowledge-base build drift") | .run')
[[ "$drift_command" == "git diff --exit-code -- plugins/knowledge-base/dist" ]]
```

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```bash
bats tests/knowledge-base/knowledge-base-specific.bats tests/github_workflows.bats
bun run --cwd plugins/knowledge-base test -- package.test.ts
```

Expected: FAIL because `dist/` is ignored/untracked, `.mcp.json` uses the global binary, and CI lacks the drift step.

- [ ] **Step 3: Allow only knowledge-base dist and build it**

Add immediately after the root `dist/` ignore:

```gitignore
!plugins/knowledge-base/dist/
!plugins/knowledge-base/dist/**
```

Run:

```bash
bun run --cwd plugins/knowledge-base build
git add plugins/knowledge-base/dist
```

Do not add any other ignored `dist/` directory.

- [ ] **Step 4: Make the plugin-local launcher the MCP default**

Replace `.mcp.json` args with:

```json
[
  "-lc",
  "exec \"${KNOWLEDGE_BASE_BIN:-${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$PWD}}/bin/knowledge-base.mjs}\" mcp"
]
```

Keep `command: "sh"` and `cwd: "."`.

- [ ] **Step 5: Add the CI drift step**

Insert after `Build knowledge-base package`:

```yaml
- name: Check knowledge-base build drift
  run: git diff --exit-code -- plugins/knowledge-base/dist
```

The normal package tests and root tests remain separate later steps.

- [ ] **Step 6: Run focused GREEN tests**

Run:

```bash
bun run --cwd plugins/knowledge-base build
bats tests/knowledge-base/knowledge-base-specific.bats tests/github_workflows.bats
bun run --cwd plugins/knowledge-base test -- package.test.ts
git diff --exit-code -- plugins/knowledge-base/dist
```

Expected: all commands PASS.

- [ ] **Step 7: Commit Task 2**

```bash
git add \
  .gitignore \
  .github/workflows/ci.yml \
  plugins/knowledge-base/.mcp.json \
  plugins/knowledge-base/dist \
  plugins/knowledge-base/tests/package.test.ts \
  tests/github_workflows.bats \
  tests/knowledge-base/knowledge-base-specific.bats
git commit -m "build(knowledge-base): ship reproducible plugin runtime"
```

---

### Task 3: Release lock synchronization and user-facing setup

**Files:**
- Modify: `.releaserc.js:64-80,124-130`
- Modify: `tests/github_workflows.bats:155-193`
- Modify: `plugins/knowledge-base/README.md`

**Interfaces:**
- Consumes: nested `package-lock.json` from Task 1.
- Produces: release preparation updating `package.json.version`, `package-lock.json.version`, and `package-lock.json.packages[""].version` to the same semantic-release version.
- Produces: release asset `plugins/knowledge-base/package-lock.json`.

- [ ] **Step 1: Extend release tests for the nested lock**

In the release fixture, write:

```js
await writeFile(
  join(fixture, "plugins", "knowledge-base", "package-lock.json"),
  JSON.stringify({
    name: "@baleen37/knowledge-base",
    version: "0.0.0",
    lockfileVersion: 3,
    packages: {
      "": {
        name: "@baleen37/knowledge-base",
        version: "0.0.0",
      },
    },
  }, null, 2) + "\n",
);
```

After `prepare`, assert:

```js
const lock = JSON.parse(await readFile(
  join(fixture, "plugins", "knowledge-base", "package-lock.json"),
  "utf8",
));
if (lock.version !== "99.0.0") {
  throw new Error(`nested lock version: ${lock.version}`);
}
if (lock.packages[""].version !== "99.0.0") {
  throw new Error(`nested lock root version: ${lock.packages[""].version}`);
}
```

Extend the git-assets test:

```js
if (!git[1].assets.includes("plugins/knowledge-base/package-lock.json")) {
  throw new Error("nested knowledge-base package lock is not a release asset");
}
```

- [ ] **Step 2: Run the workflow tests to verify RED**

Run:

```bash
bats tests/github_workflows.bats
```

Expected: FAIL because release prepare and git assets do not include the lockfile.

- [ ] **Step 3: Update release preparation**

After writing `package.json`, read and update the lock:

```js
const knowledgeBaseLockPath = resolve(
  process.cwd(),
  "plugins",
  "knowledge-base",
  "package-lock.json",
);
const knowledgeBaseLock = JSON.parse(readFileSync(knowledgeBaseLockPath, "utf8"));
knowledgeBaseLock.version = version;
knowledgeBaseLock.packages[""].version = version;
writeFileSync(
  knowledgeBaseLockPath,
  JSON.stringify(knowledgeBaseLock, null, 2) + "\n",
);
```

Add this exact release asset beside the nested package:

```js
"plugins/knowledge-base/package-lock.json",
```

- [ ] **Step 4: Update README for plugin-local operation**

Replace the unpublished global-install example with:

```bash
# From a bstack checkout
./plugins/knowledge-base/bin/knowledge-base.mjs setup --repo <owner/repository>
./plugins/knowledge-base/bin/knowledge-base.mjs sync
./plugins/knowledge-base/bin/knowledge-base.mjs search "<query>"
```

Document these facts in plain language:

- Claude/Codex invokes the same launcher automatically for MCP.
- First launch installs locked production dependencies inside the plugin directory.
- The embedding model is downloaded separately to the existing user-local cache.
- The launcher does not add itself to global `PATH`.

- [ ] **Step 5: Run release and documentation verification**

Run:

```bash
bats tests/github_workflows.bats
bun run --cwd plugins/knowledge-base test -- package.test.ts
npm pack --dry-run --json --ignore-scripts \
  --workspace plugins/knowledge-base
```

Expected: release tests PASS; tarball contains `bin/`, `dist/`, README, LICENSE, and package metadata but no lockfile, private content, SQLite, GGUF, or config.

- [ ] **Step 6: Commit Task 3**

```bash
git add \
  .releaserc.js \
  plugins/knowledge-base/README.md \
  tests/github_workflows.bats
git commit -m "build(knowledge-base): synchronize plugin runtime releases"
```

---

### Task 4: Fresh-install CLI and MCP end-to-end smoke

**Files:**
- Create: `plugins/knowledge-base/tests/plugin-runtime.test.ts`
- Modify: `.github/workflows/ci.yml`
- Modify: `tests/github_workflows.bats`

**Interfaces:**
- Consumes: the tracked public plugin files, launcher, `package-lock.json`, and MCP SDK.
- Produces: opt-in `KNOWLEDGE_BASE_REAL_PLUGIN=1` smoke that runs real `npm ci` in an isolated temporary plugin copy.
- Produces: CI step named `Test knowledge-base plugin runtime`.

- [ ] **Step 1: Write the opt-in fresh-plugin smoke**

Create `tests/plugin-runtime.test.ts` with an opt-in test:

```ts
const enabled = process.env.KNOWLEDGE_BASE_REAL_PLUGIN === "1";
const pluginRuntimeTest = enabled ? it : it.skip;

describe("plugin-local runtime", () => {
  pluginRuntimeTest("bootstraps dependencies and serves MCP from a fresh copy", async () => {
    const fixture = await copyPublicPluginFixture();
    const launcher = join(fixture, "bin", "knowledge-base.mjs");

    expect(await pathExists(join(fixture, "node_modules"))).toBe(false);

    const version = await execFile(process.execPath, [launcher, "--version"], {
      env: isolatedEnvironment(fixture),
      timeout: 10 * 60_000,
    });
    expect(version.stderr).toBe("");
    expect(version.stdout).toBe(`${expectedVersion}\n`);
    expect(await pathExists(join(
      fixture,
      "node_modules",
      "@tobilu",
      "qmd",
    ))).toBe(true);

    const transport = new StdioClientTransport({
      command: process.execPath,
      args: [launcher, "mcp"],
      env: isolatedEnvironment(fixture),
      stderr: "pipe",
    });
    const client = new Client({
      name: "knowledge-base-plugin-runtime",
      version: "1.0.0",
    });
    try {
      await client.connect(transport);
      const { tools } = await client.listTools();
      expect(tools.map((tool) => tool.name).sort())
        .toEqual(["get", "search", "status"]);
      expect(client.getServerVersion()).toEqual({
        name: "knowledge-base",
        version: expectedVersion,
      });
    } finally {
      await client.close();
    }
  }, 15 * 60_000);
});
```

`copyPublicPluginFixture()` must copy only:

```text
bin/
dist/
package.json
package-lock.json
README.md
LICENSE
```

`isolatedEnvironment()` must put config, data, cache, and npm cache under the
test's `mkdtemp` root:

```ts
{
  ...process.env,
  KNOWLEDGE_BASE_CONFIG_DIR: join(root, "config"),
  KNOWLEDGE_BASE_DATA_DIR: join(root, "data"),
  KNOWLEDGE_BASE_CACHE_DIR: join(root, "cache"),
  npm_config_cache: join(root, "npm-cache"),
}
```

The test teardown must remove the exact temporary root and restore the original
environment. It must capture and require empty child stderr after MCP close,
using the same bounded stderr-drain pattern as `mcp.test.ts`.

- [ ] **Step 2: Run normal tests to verify the smoke is skipped**

Run:

```bash
bun run --cwd plugins/knowledge-base test -- plugin-runtime.test.ts
```

Expected: one skipped test, exit zero.

- [ ] **Step 3: Run the real fresh-plugin smoke**

Run:

```bash
KNOWLEDGE_BASE_REAL_PLUGIN=1 \
  bun run --cwd plugins/knowledge-base test -- plugin-runtime.test.ts
```

Expected: PASS; npm installs only inside the temporary plugin fixture, the CLI
prints the package version, MCP lists exactly three tools, and teardown removes
the fixture.

- [ ] **Step 4: Add the CI runtime step and its workflow contract**

Insert after the normal package test:

```yaml
- name: Test knowledge-base plugin runtime
  env:
    KNOWLEDGE_BASE_REAL_PLUGIN: "1"
  run: bun run --cwd plugins/knowledge-base test -- plugin-runtime.test.ts
```

Add a BATS assertion:

```bash
runtime_command=$(yaml_get "$CI_WORKFLOW" \
  '.jobs.test.steps[] | select(.name == "Test knowledge-base plugin runtime") | .run')
runtime_opt_in=$(yaml_get "$CI_WORKFLOW" \
  '.jobs.test.steps[] | select(.name == "Test knowledge-base plugin runtime") | .env.KNOWLEDGE_BASE_REAL_PLUGIN')
[[ "$runtime_command" == \
  "bun run --cwd plugins/knowledge-base test -- plugin-runtime.test.ts" ]]
[[ "$runtime_opt_in" == "1" ]]
```

Keep `KNOWLEDGE_BASE_REAL_MODEL=1` absent from CI.

- [ ] **Step 5: Run the complete verification gate**

Run:

```bash
bun install --frozen-lockfile
bun run --cwd plugins/knowledge-base build
git diff --exit-code -- plugins/knowledge-base/dist
bun run --cwd plugins/knowledge-base typecheck
bun run --cwd plugins/knowledge-base test
KNOWLEDGE_BASE_REAL_PLUGIN=1 \
  bun run --cwd plugins/knowledge-base test -- plugin-runtime.test.ts
bun run test
bun run check:codex
git diff --check
git status --short
```

Expected:

- Build and typecheck exit zero.
- All normal package tests pass with real-model and real-plugin opt-ins skipped;
  the dedicated real-plugin invocation then passes, leaving only real-model
  intentionally unexecuted.
- Real plugin runtime test passes.
- Root, integration, plugin, and stdio BATS suites pass.
- Codex artifacts have no drift.
- `dist/` has no generated drift.
- Worktree contains only the intended Task 4 changes before commit.

- [ ] **Step 6: Commit Task 4**

```bash
git add \
  .github/workflows/ci.yml \
  plugins/knowledge-base/tests/plugin-runtime.test.ts \
  tests/github_workflows.bats
git commit -m "test(knowledge-base): verify fresh plugin runtime"
```

---

## Final Review Checklist

- [ ] Review `origin/main..HEAD` for private paths, Markdown content, SQLite, GGUF, config, `node_modules`, and npm cache artifacts.
- [ ] Run `git ls-files plugins/knowledge-base/dist` and confirm every file is generated by the package build.
- [ ] Run `npm pack --dry-run --json --ignore-scripts --workspace plugins/knowledge-base` and inspect the complete file list.
- [ ] Verify the launcher succeeds from a path containing spaces.
- [ ] Verify MCP stdout remains JSON-RPC-only during both existing-dependency and first-bootstrap paths.
- [ ] Verify release prepare changes package and package-lock versions together.
- [ ] Confirm npm publication was not executed.
- [ ] Request independent code review before integration.
