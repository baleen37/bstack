#!/usr/bin/env bats
# build-index.ts 단위 테스트

bats_require_minimum_version 1.5.0
load ../helpers/bats_helper

INDEXER="${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts"
FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/sample-session.jsonl"

@test "evolve build-index: counts turns and user messages" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.turns_total == 9'
    echo "$output" | jq -e '.user_messages == 3'
}

@test "evolve build-index: detects user_correction signal" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "user_correction")] | length >= 1'
}

@test "evolve build-index: detects verbose_exploration (repeated grep)" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "verbose_exploration")] | length >= 1'
}

@test "evolve build-index: detects success_pattern after positive feedback" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "success_pattern")] | length >= 1'
}

@test "evolve build-index: tools_top includes Bash and Read" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.tools_top | map(.[0]) | index("Bash") != null'
}

@test "evolve build-index: extracts skill_invocations from /<name> messages" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.skill_invocations | length >= 1'
    echo "$output" | jq -e '.skill_invocations[0].name == "me:browse"'
}

@test "evolve build-index: --skill filter keeps only matching groups" {
    run bun "$INDEXER" "$FIXTURE" --skill me:browse
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.skill_invocations | all(.name == "me:browse")'
}
