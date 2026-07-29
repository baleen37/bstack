# @baleen37/knowledge-base

Local hybrid search for a private Markdown knowledge base.

```bash
bun add -g @baleen37/knowledge-base
knowledge-base setup --repo <repository>
knowledge-base sync
knowledge-base index
knowledge-base search <query>
knowledge-base get qmd://personal/<path>
knowledge-base status
```

All repository clones, indexes, models, and search data remain local to your
machine. Do not use this package to publish private knowledge-base content.

## Running as a plugin

The plugin ships its built CLI in `dist/` and runs it in place, so no global
install is needed:

```sh
exec node "${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$PWD}}/dist/cli.js" mcp
```

Codex sets `PLUGIN_ROOT` and Claude Code sets `CLAUDE_PLUGIN_ROOT`. Neither
expands the other's variable, so a shell evaluates the fallback chain.

Runtime dependencies are not committed. qmd pulls in platform-specific native
modules — `node-llama-cpp`, `better-sqlite3`, `sqlite-vec` — which cannot be
built for one platform and reused on another. A `SessionStart` hook installs
them once per machine into `$CLAUDE_PLUGIN_DATA/runtime` and symlinks the
result next to `dist/`. The symlink is what makes resolution work: Node's ESM
resolver ignores `NODE_PATH`.

The first session after installing the plugin compiles native addons and lands
about 185 MB in that directory, which can take a few minutes. The MCP server
may fail to start during that window; it connects normally once the hook
finishes. Later sessions skip the install unless the dependency set changes.

npm 12 blocks dependency install scripts by default, so the generated manifest
lists the native packages under `allowScripts`. If a future qmd release adds
another one, the hook stops with the package name instead of leaving a tree
that looks complete but fails on a missing binding.
