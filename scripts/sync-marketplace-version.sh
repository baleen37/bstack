#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

MARKETPLACE_FILE="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
TMP_FILE="$(mktemp "${MARKETPLACE_FILE}.tmp.XXXXXX")"

cleanup() {
  rm -f "${TMP_FILE}"
}
trap cleanup EXIT

versions_json='{}'
for plugin_json in "${PROJECT_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
  [ -f "${plugin_json}" ] || continue

  plugin_name="$(basename "$(dirname "$(dirname "${plugin_json}")")")"
  plugin_version="$(jq -r '.version' "${plugin_json}")"

  versions_json="$(jq -n \
    --argjson versions "${versions_json}" \
    --arg plugin_name "${plugin_name}" \
    --arg plugin_version "${plugin_version}" \
    '$versions + {($plugin_name): $plugin_version}'
  )"
done

jq \
  --argjson versions "${versions_json}" \
  '.plugins |= map(
    . as $plugin
    | ($plugin.source // "") as $source
    | if ($source | startswith("./plugins/")) then
        ($source | ltrimstr("./plugins/")) as $plugin_name
        | if $versions[$plugin_name] != null then
            .version = $versions[$plugin_name]
          else
            .
          end
      else
        .
      end
  )' \
  "${MARKETPLACE_FILE}" > "${TMP_FILE}"

if cmp -s "${MARKETPLACE_FILE}" "${TMP_FILE}"; then
  exit 0
fi

mv "${TMP_FILE}" "${MARKETPLACE_FILE}"
