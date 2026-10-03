#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

@test "harness audit recognizes the skills project name" {
    local project_root="${BATS_TEST_TMPDIR}/skills-project"
    mkdir -p "$project_root"
    printf '%s\n' '{"name":"skills","scripts":{"test":"true"}}' > "$project_root/package.json"

    run env AUDIT_ROOT="$project_root" node "${PROJECT_ROOT}/scripts/harness-audit.js" --format json

    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -r '.target_mode')" = "repo" ]
}
