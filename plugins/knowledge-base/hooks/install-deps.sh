#!/usr/bin/env bash
# Install the knowledge-base MCP server's runtime dependencies.
#
# The plugin ships dist/ but not node_modules. qmd pulls in platform-specific
# native modules (node-llama-cpp, better-sqlite3, sqlite-vec), so they cannot be
# committed for one platform and reused on another. They are installed once per
# machine into a directory that survives plugin updates, then linked next to
# dist/ because Node's ESM resolver ignores NODE_PATH.
set -euo pipefail

root="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$PWD}}"
deps="${CLAUDE_PLUGIN_DATA:-${XDG_DATA_HOME:-${HOME}/.local/share}/knowledge-base}/runtime"

manifest="${root}/package.json"
stamp="${deps}/.installed.json"

if [ ! -f "$manifest" ]; then
    echo "knowledge-base: missing ${manifest}" >&2
    exit 1
fi

for tool in npm jq; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "knowledge-base: ${tool} is required to install the search dependencies" >&2
        exit 1
    fi
done

# npm 12 blocks dependency install scripts unless the manifest allows them.
# These are the native modules qmd needs; skipping their build step leaves the
# tree looking complete while every search fails on a missing .node binding.
# Entries are deliberately unpinned so a qmd patch bump does not silently
# reintroduce the block.
allow_scripts='{
  "better-sqlite3": true,
  "node-llama-cpp": true,
  "tree-sitter-go": true,
  "tree-sitter-javascript": true,
  "tree-sitter-python": true,
  "tree-sitter-rust": true,
  "tree-sitter-typescript": true
}'

# Install runtime dependencies only. Copying the whole manifest would drag in
# devDependencies, whose typescript pin conflicts with the peer range qmd asks
# for and fails resolution outright.
runtime="$(jq -S --argjson allow "$allow_scripts" '{
  name: "knowledge-base-runtime",
  private: true,
  type: .type,
  dependencies: .dependencies,
  allowScripts: $allow
}' "$manifest")"

# The stamp is written only after a successful install, so an interrupted run
# retries instead of being mistaken for an up-to-date tree.
if [ ! -d "${deps}/node_modules" ] || [ "$runtime" != "$(cat "$stamp" 2>/dev/null)" ]; then
    mkdir -p "$deps"
    printf '%s\n' "$runtime" > "${deps}/package.json"
    npm install --omit=dev --prefix "$deps" >&2

    # A newly added native dependency would be blocked and skipped silently.
    # Fail here rather than at the first search.
    if ! (cd "$deps" && npm install-scripts ls 2>/dev/null) |
        grep -q "No packages with unreviewed install scripts"; then
        echo "knowledge-base: dependencies with blocked install scripts remain:" >&2
        (cd "$deps" && npm install-scripts ls) >&2
        echo "knowledge-base: review them, then add them to allow_scripts in $0" >&2
        exit 1
    fi

    printf '%s\n' "$runtime" > "$stamp"
fi

# A real node_modules means this is a source checkout that manages its own
# dependencies; leave it alone.
if [ ! -e "${root}/node_modules" ]; then
    ln -s "${deps}/node_modules" "${root}/node_modules"
fi
