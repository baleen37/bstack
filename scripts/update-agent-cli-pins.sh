#!/usr/bin/env bash
# Bump the pinned Claude Code and Codex CLI versions in the CI and Release
# workflows to the newest npm release that is at least MIN_AGE_DAYS old
# (npm allows unpublishing within 72 hours) and not newer than `latest`.
# Never downgrades. Prints "<pkg> <old> -> <new>" for each bump.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd -- "${SCRIPT_DIR}/.." && pwd)}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org}"
MIN_AGE_DAYS="${MIN_AGE_DAYS:-3}"
NOW="${NOW:-$(date +%s)}"

PACKAGES=(@anthropic-ai/claude-code @openai/codex)
FILES=("${PROJECT_ROOT}/.github/workflows/ci.yml" "${PROJECT_ROOT}/.github/workflows/release.yml")

# Newest stable version released before the cutoff and <= dist-tags.latest.
pick_version() {
    local metadata="$1"
    jq -r --argjson cutoff "$((NOW - MIN_AGE_DAYS * 86400))" '
        def semver: split(".") | map(tonumber);
        (.["dist-tags"].latest | semver) as $latest
        | .time
        | to_entries
        | map(select(.key | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")))
        | map(select((.value | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) <= $cutoff))
        | map(select((.key | semver) <= $latest))
        | sort_by(.key | semver)
        | last
        | .key // empty
    ' <<< "$metadata"
}

for pkg in "${PACKAGES[@]}"; do
    current=$(grep -ohE "${pkg}@[0-9]+\.[0-9]+\.[0-9]+" "${FILES[@]}" | head -1 | sed "s|^${pkg}@||")
    if [ -z "$current" ]; then
        echo "error: no pinned ${pkg} version found" >&2
        exit 1
    fi

    metadata=$(curl -fsSL "${NPM_REGISTRY}/${pkg/\//%2f}")
    candidate=$(pick_version "$metadata")
    [ -n "$candidate" ] || continue

    newest=$(printf '%s\n%s\n' "$current" "$candidate" | sort -V | tail -1)
    [ "$newest" != "$current" ] || continue

    sed -i.bak "s|${pkg}@${current}|${pkg}@${candidate}|g" "${FILES[@]}"
    for f in "${FILES[@]}"; do rm -f "${f}.bak"; done
    echo "${pkg} ${current} -> ${candidate}"
done
