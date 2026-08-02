#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
OPENCODE_ROOT="${PROJECT_ROOT}/.opencode"
CONFIG_ROOT="${OPENCODE_CONFIG_DIR:-${HOME}/.config/opencode}"

if [ ! -d "${OPENCODE_ROOT}" ]; then
  echo "Missing ${OPENCODE_ROOT}; run 'bun run sync:opencode' first" >&2
  exit 1
fi

mkdir -p "${CONFIG_ROOT}/skills" "${CONFIG_ROOT}/agents" "${CONFIG_ROOT}/command" "${CONFIG_ROOT}/plugins"

link_or_backup() {
  local target="$1"
  local link_path="$2"

  if [ -e "${link_path}" ] && [ ! -L "${link_path}" ]; then
    echo "Backing up existing ${link_path} to ${link_path}.bak" >&2
    mv "${link_path}" "${link_path}.bak"
  fi

  ln -sfn "${target}" "${link_path}"
}

for skill_dir in "${OPENCODE_ROOT}"/skills/*; do
  [ -d "${skill_dir}" ] || continue
  link_or_backup "${skill_dir}" "${CONFIG_ROOT}/skills/$(basename "${skill_dir}")"
done

for agent_file in "${OPENCODE_ROOT}"/agents/*.md; do
  [ -f "${agent_file}" ] || continue
  link_or_backup "${agent_file}" "${CONFIG_ROOT}/agents/$(basename "${agent_file}")"
done

for cmd_file in "${OPENCODE_ROOT}"/command/*.md; do
  [ -f "${cmd_file}" ] || continue
  link_or_backup "${cmd_file}" "${CONFIG_ROOT}/command/$(basename "${cmd_file}")"
done

link_or_backup "${OPENCODE_ROOT}/plugins/bstack.ts" "${CONFIG_ROOT}/plugins/bstack.ts"

echo "Installed OpenCode artifacts into ${CONFIG_ROOT}"
