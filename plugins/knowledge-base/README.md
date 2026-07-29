# @baleen37/knowledge-base

Local hybrid search for a private Markdown knowledge base.

```bash
# From a bstack checkout
./plugins/knowledge-base/bin/knowledge-base.mjs setup --repo <owner/repository>
./plugins/knowledge-base/bin/knowledge-base.mjs sync
./plugins/knowledge-base/bin/knowledge-base.mjs search "<query>"
```

Claude and Codex invoke this same launcher automatically when they use the MCP
server. On its first launch, the launcher installs the locked production
dependencies inside the plugin directory. It downloads the embedding model
separately to the existing user-local cache. The launcher does not add itself to
the global `PATH`.

All repository clones, indexes, models, and search data remain local to your
machine. Do not use this package to publish private knowledge-base content.
