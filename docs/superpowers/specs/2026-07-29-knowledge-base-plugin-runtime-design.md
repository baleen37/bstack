# Knowledge Base Plugin Runtime Design

## Goal

Installing the `knowledge-base` plugin from bstack must be enough to run its
CLI and local stdio MCP server. Users must not need to install
`@baleen37/knowledge-base` globally first.

The plugin will follow the repository's existing local-runtime pattern:
checked-in build output, a plugin-local launcher, and one-time installation of
runtime dependencies inside the plugin directory.

## Chosen Approach

Track `plugins/knowledge-base/dist/**` and add a
`plugins/knowledge-base/bin/knowledge-base.mjs` launcher.

The launcher will:

1. Resolve the plugin root relative to its own file.
2. Check for the three direct runtime dependencies:
   `@modelcontextprotocol/sdk`, `@tobilu/qmd`, and `zod`.
3. Run `npm ci --omit=dev --no-audit --no-fund` in the plugin root when any
   dependency is missing.
4. Keep dependency-install output off stdout so stdio MCP JSON-RPC remains
   clean. Installation diagnostics are written to stderr only on failure.
5. Import the checked-in `dist/cli.js` and run the CLI in the same Node process.

The existing pinned embedding model remains a separate runtime download into
the user's local knowledge-base cache. Neither models nor private content are
stored in the plugin.

## Alternatives Rejected

### Track TypeScript output only

The generated JavaScript still imports qmd, SQLite, llama, and MCP packages.
Without runtime dependencies, the plugin would contain `dist/` but fail at
startup.

### Platform-specific executable bundles

qmd depends on native SQLite, sqlite-vec, and llama components. Shipping
standalone binaries would require a multi-platform release matrix and native
artifact management. That is unnecessary for the current local plugin.

### Require a global npm install

This is the current behavior. It leaves the bstack plugin incomplete until the
user performs a separate installation, which does not meet the goal.

## Repository Changes

### Tracked build

The root `.gitignore` will explicitly allow:

```text
plugins/knowledge-base/dist/
plugins/knowledge-base/dist/**
```

The TypeScript build remains the single source of generated files. CI will
build the package and fail if the tracked `dist/` differs from the generated
output.

### Launcher and CLI

`bin/knowledge-base.mjs` will be the package `bin` target and the plugin-local
entrypoint. The CLI module will expose a small `main()` function so the launcher
can run it in-process. The existing direct `dist/cli.js` entrypoint will keep
working.

The plugin provides a CLI at its installed plugin path. It does not modify the
user's global `PATH`. A future npm publication may additionally provide the
same launcher as a global `knowledge-base` command.

### MCP configuration

`.mcp.json` will invoke the plugin-local launcher with `mcp`, using the same
plugin-root fallback convention as other bstack local MCP plugins. It will no
longer depend on a global `knowledge-base` binary. The existing
`KNOWLEDGE_BASE_BIN` override remains available for explicit development or
diagnostic use; the plugin-local launcher is the default.

### Runtime dependency lock

The plugin will include its own `package-lock.json`, generated from the nested
package with production and development dependencies pinned. Runtime bootstrap
uses that lock through `npm ci`.

Semantic release preparation will update the nested package version and the
matching root package version fields in `package-lock.json`, then commit both
files as release assets. The existing package version remains the version
reported by the CLI and MCP server.

## Data and Failure Behavior

- Runtime dependencies are installed only under the plugin directory.
- Knowledge checkout, configuration, index, and model paths remain under the
  existing user-local directories.
- No dependency installer output is written to stdout.
- A failed dependency install returns a non-zero exit with a concise stderr
  error and does not start the CLI or MCP server.
- A complete dependency set skips npm entirely on later starts.

## Verification

Tests will prove:

1. `dist/**`, the launcher, and the nested lockfile are tracked.
2. A fresh plugin copy without `node_modules` bootstraps production
   dependencies and runs `--version`.
3. The same fresh copy completes MCP initialize and lists exactly
   `get`, `search`, and `status`, with no stdout banner.
4. An existing complete dependency set does not invoke npm.
5. A failed npm bootstrap exits non-zero and preserves stdout purity.
6. `.mcp.json` invokes the plugin-local launcher and contains no global CLI,
   `npx`, or `bunx` dependency.
7. Building leaves no `dist/` drift.
8. The npm tarball still contains only public runtime files and excludes
   private content, config, SQLite databases, and GGUF models.
9. Release preparation keeps `package.json` and `package-lock.json` versions
   synchronized.

The existing opt-in real-model test remains unchanged because runtime
packaging does not alter model verification, indexing, or retrieval behavior.
