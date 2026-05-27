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

@test "evolve build-index: fixture produces well-formed index with all signal kinds" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # 모든 4종(또는 fixture가 만들 수 있는 3종) 신호 종류가 최소 1개씩
    local kinds
    kinds=$(echo "$output" | jq -r '[.groups[].signals[].kind] | unique | sort | join(",")')
    [[ "$kinds" == *"success_pattern"* ]]
    [[ "$kinds" == *"user_correction"* ]]
    [[ "$kinds" == *"verbose_exploration"* ]]
    # 인덱스 자체 형식 검증
    echo "$output" | jq -e '.session_id and .jsonl_path and .turns_total and (.groups | type == "array")'
}

INTERRUPT_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/interrupt-session.jsonl"

@test "evolve build-index: detects interrupt signal" {
    run bun "$INDEXER" "$INTERRUPT_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "interrupt")] | length >= 1'
}

@test "evolve build-index: dirty tree guard exits 13" {
    # 임시 디렉토리에 가짜 git repo + dirty 상태 만들기
    local tmp="$BATS_TEST_TMPDIR/dirty-repo"
    mkdir -p "$tmp"
    cd "$tmp"
    git init -q
    git config user.email t@t && git config user.name t
    echo "x" > a && git add a && git commit -q -m init
    echo "dirty" > a   # uncommitted change
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 13 ]
}

@test "evolve build-index: --no-dirty-check bypasses guard" {
    local tmp="$BATS_TEST_TMPDIR/dirty-bypass"
    mkdir -p "$tmp"
    cd "$tmp"
    git init -q
    git config user.email t@t && git config user.name t
    echo "x" > a && git add a && git commit -q -m init
    echo "dirty" > a
    run bun "$INDEXER" "$FIXTURE" --no-dirty-check
    [ "$status" -eq 0 ]
}

@test "evolve build-index: missing transcript dir exits 14" {
    # 점이 포함된 절대 경로로 cd → encodeCwd 결과는 존재하지 않을 것
    local tmp="$BATS_TEST_TMPDIR/no.such.transcript.dir/nested"
    mkdir -p "$tmp"
    cd "$tmp"
    # 이 경로에 .git이 없어 dirty 가드는 건너뜀, encodeCwd로 만든 디렉토리는 ~/.claude/projects/에 없음
    run bun "$INDEXER" --no-dirty-check
    [ "$status" -eq 14 ]
}
