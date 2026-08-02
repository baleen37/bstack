#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CLAUDE_MARKETPLACE="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
PLUGINS_ROOT="${PROJECT_ROOT}/plugins"
OPENCODE_ROOT="${PROJECT_ROOT}/.opencode"

eligible_plugins() {
  jq -r '.plugins[].source' "${CLAUDE_MARKETPLACE}" | sed 's|^\./plugins/||'
}

convert_agent() {
  awk '
    BEGIN { infm = 0; closed = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !closed {
      if ($0 == "---") {
        print "mode: subagent"
        closed = 1
        print
        next
      }
      if ($0 ~ /^model:/) { next }
      print
      next
    }
    { print }
  ' "$1"
}

convert_command() {
  awk '
    BEGIN { infm = 0; closed = 0; skip = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !closed {
      if ($0 == "---") { closed = 1; print; next }
      if (skip && $0 ~ /^[^[:space:]]/) { skip = 0 }
      if (skip) { next }
      if ($0 ~ /^(argument-hint|allowed-tools):/) { skip = 1; next }
      print
      next
    }
    { print }
  ' "$1"
}

tmp_root="$(mktemp -d "${OPENCODE_ROOT}.tmp.XXXXXX")"
trap 'rm -rf "${tmp_root}"' EXIT

mkdir -p "${tmp_root}/skills" "${tmp_root}/agents" "${tmp_root}/command" "${tmp_root}/plugins"

generated_any=0

while IFS= read -r plugin_name; do
  [ -n "${plugin_name}" ] || continue
  plugin_dir="${PLUGINS_ROOT}/${plugin_name}"
  [ -d "${plugin_dir}" ] || continue

  if [ -d "${plugin_dir}/skills" ]; then
    for skill_dir in "${plugin_dir}"/skills/*/; do
      [ -d "${skill_dir}" ] || continue
      skill_name="$(basename "${skill_dir}")"
      target="${tmp_root}/skills/${skill_name}"
      if [ -e "${target}" ]; then
        echo "Skill name collision: ${skill_name}" >&2
        exit 1
      fi
      cp -R "${skill_dir}" "${target}"
    done
  fi

  if [ -d "${plugin_dir}/agents" ]; then
    for agent_file in "${plugin_dir}"/agents/*.md; do
      [ -f "${agent_file}" ] || continue
      convert_agent "${agent_file}" > "${tmp_root}/agents/$(basename "${agent_file}")"
    done
  fi

  if [ -d "${plugin_dir}/commands" ]; then
    for cmd_file in "${plugin_dir}"/commands/*.md; do
      [ -f "${cmd_file}" ] || continue
      convert_command "${cmd_file}" > "${tmp_root}/command/$(basename "${cmd_file}")"
    done
  fi

  generated_any=1
done < <(eligible_plugins)

cp "${SCRIPT_DIR}/opencode-plugin/bstack.ts" "${tmp_root}/plugins/bstack.ts"

if [ "${generated_any}" -eq 1 ]; then
  rm -rf "${OPENCODE_ROOT}"
  mv "${tmp_root}" "${OPENCODE_ROOT}"
  trap - EXIT
fi
