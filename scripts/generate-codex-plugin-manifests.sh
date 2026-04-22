#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CLAUDE_MARKETPLACE="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
PLUGINS_ROOT="${PROJECT_ROOT}/plugins"

eligible_plugins() {
  jq -r '.plugins[].source' "${CLAUDE_MARKETPLACE}" | sed 's|^\./plugins/||'
}

is_skill_plugin() {
  local plugin_name="$1"
  [ -d "${PLUGINS_ROOT}/${plugin_name}/skills" ]
}

render_manifest() {
  local claude_manifest="$1"
  jq '
    . + {skills: "./skills/"} |
    with_entries(select(.value != null))
  ' "${claude_manifest}"
}

generated_any=0

while IFS= read -r plugin_name; do
  [ -n "${plugin_name}" ] || continue
  is_skill_plugin "${plugin_name}" || continue

  plugin_dir="${PLUGINS_ROOT}/${plugin_name}"
  claude_manifest="${plugin_dir}/.claude-plugin/plugin.json"
  codex_dir="${plugin_dir}/.codex-plugin"
  codex_manifest="${codex_dir}/plugin.json"
  tmp_file="$(mktemp "${codex_manifest}.tmp.XXXXXX")"

  mkdir -p "${codex_dir}"
  render_manifest "${claude_manifest}" > "${tmp_file}"

  if [ ! -f "${codex_manifest}" ] || ! cmp -s "${tmp_file}" "${codex_manifest}"; then
    mv "${tmp_file}" "${codex_manifest}"
  else
    rm -f "${tmp_file}"
  fi

  generated_any=1
done < <(eligible_plugins)

find "${PLUGINS_ROOT}" -mindepth 2 -maxdepth 2 -type d -name '.codex-plugin' | while IFS= read -r codex_dir; do
  plugin_name="$(basename "$(dirname "${codex_dir}")")"
  if ! is_skill_plugin "${plugin_name}" || ! eligible_plugins | grep -qx "${plugin_name}"; then
    rm -f "${codex_dir}/plugin.json"
    rmdir "${codex_dir}" 2>/dev/null || true
  fi
done

[ "${generated_any}" -eq 1 ]
