#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CLAUDE_MARKETPLACE="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
CODEX_MARKETPLACE="${PROJECT_ROOT}/.agents/plugins/marketplace.json"

mkdir -p "$(dirname "${CODEX_MARKETPLACE}")"

codex_plugins='[]'

while IFS= read -r plugin_name; do
  [ -d "${PROJECT_ROOT}/plugins/${plugin_name}/skills" ] || continue

  codex_plugins="$(
    jq -n \
      --argjson plugins "${codex_plugins}" \
      --arg plugin_name "${plugin_name}" '
        $plugins + [{
          name: $plugin_name,
          source: {
            source: "local",
            path: ("./plugins/" + $plugin_name)
          },
          policy: {
            installation: "AVAILABLE",
            authentication: "ON_INSTALL"
          },
          category: "Productivity"
        }]
      '
  )"
done < <(
  jq -r '.plugins[].source' "${CLAUDE_MARKETPLACE}" | sed 's|^\./plugins/||'
)

tmp_file="$(mktemp "${CODEX_MARKETPLACE}.tmp.XXXXXX")"

jq -n \
  --arg marketplace_name "$(jq -r '.name' "${CLAUDE_MARKETPLACE}")" \
  --argjson plugins "${codex_plugins}" '
    {
      name: $marketplace_name,
      interface: {
        displayName: $marketplace_name
      },
      plugins: $plugins
    }
  ' > "${tmp_file}"

if [ ! -f "${CODEX_MARKETPLACE}" ] || ! cmp -s "${tmp_file}" "${CODEX_MARKETPLACE}"; then
  mv "${tmp_file}" "${CODEX_MARKETPLACE}"
else
  rm -f "${tmp_file}"
fi
