#!/usr/bin/env bats
# Test: scripts/update-agent-cli-pins.sh against a fake npm registry.

load helpers/bats_helper

SCRIPT="${PROJECT_ROOT}/scripts/update-agent-cli-pins.sh"
# 2026-10-10T00:00:00Z
NOW_TS=1791590400

setup() {
    ensure_jq
    export FAKE_ROOT="${BATS_TEST_TMPDIR}/repo"
    export FAKE_REGISTRY="${BATS_TEST_TMPDIR}/registry"
    mkdir -p "${FAKE_ROOT}/.github/workflows" "${FAKE_REGISTRY}/@anthropic-ai" "${FAKE_REGISTRY}/@openai"
    for wf in ci release; do
        printf '      - run: npm install -g @anthropic-ai/claude-code@2.1.10 @openai/codex@0.150.0\n' \
            > "${FAKE_ROOT}/.github/workflows/${wf}.yml"
    done
}

# registry_entry <file> <latest> <version=iso-time>...
registry_entry() {
    local file="$1" latest="$2"
    shift 2
    local times="{}" pair
    for pair in "$@"; do
        times=$(jq -c --arg v "${pair%%=*}" --arg t "${pair#*=}" '. + {($v): $t}' <<< "$times")
    done
    jq -n --arg latest "$latest" --argjson time "$times" \
        '{"dist-tags": {latest: $latest}, time: ({created: "2020-01-01T00:00:00.000Z"} + $time)}' > "$file"
}

run_update() {
    run env PROJECT_ROOT="$FAKE_ROOT" NPM_REGISTRY="file://${FAKE_REGISTRY}" NOW="$NOW_TS" bash "$SCRIPT"
}

@test "update-agent-cli-pins: bumps to the newest version at least 3 days old" {
    registry_entry "${FAKE_REGISTRY}/@anthropic-ai/claude-code" 2.1.13 \
        2.1.11=2026-10-01T00:00:00.000Z 2.1.12=2026-10-06T00:00:00.000Z 2.1.13=2026-10-09T00:00:00.000Z
    registry_entry "${FAKE_REGISTRY}/@openai/codex" 0.151.0 \
        0.150.1=2026-10-02T00:00:00.000Z 0.151.0=2026-10-08T00:00:00.000Z

    run_update
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"@anthropic-ai/claude-code 2.1.10 -> 2.1.12"* ]]
    [[ "$output" == *"@openai/codex 0.150.0 -> 0.150.1"* ]]
    for wf in ci release; do
        grep -q '@anthropic-ai/claude-code@2.1.12 @openai/codex@0.150.1' "${FAKE_ROOT}/.github/workflows/${wf}.yml"
    done
}

@test "update-agent-cli-pins: ignores versions above dist-tags.latest and prereleases" {
    registry_entry "${FAKE_REGISTRY}/@anthropic-ai/claude-code" 2.1.11 \
        2.1.11=2026-10-01T00:00:00.000Z 2.1.20=2026-10-01T00:00:00.000Z 2.2.0-beta.1=2026-10-01T00:00:00.000Z
    registry_entry "${FAKE_REGISTRY}/@openai/codex" 0.150.0 0.150.0=2026-09-01T00:00:00.000Z

    run_update
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [ "$output" = "@anthropic-ai/claude-code 2.1.10 -> 2.1.11" ]
}

@test "update-agent-cli-pins: never downgrades and leaves files untouched when nothing qualifies" {
    registry_entry "${FAKE_REGISTRY}/@anthropic-ai/claude-code" 2.1.11 \
        2.1.9=2026-09-01T00:00:00.000Z 2.1.11=2026-10-09T00:00:00.000Z
    registry_entry "${FAKE_REGISTRY}/@openai/codex" 0.150.0 0.149.0=2026-09-01T00:00:00.000Z

    local before
    before=$(cat "${FAKE_ROOT}"/.github/workflows/*.yml)
    run_update
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [ -z "$output" ]
    [ "$(cat "${FAKE_ROOT}"/.github/workflows/*.yml)" = "$before" ]
}
