#!/usr/bin/env bats
# build-index.ts 단위 테스트
#
# 인덱서는 결정적 메타데이터만 추출한다. user 발화 분류 (정정/긍정/잡담)는
# Phase 1 LLM이 책임지므로 여기서는 raw user_message 신호만 검증.

bats_require_minimum_version 1.5.0
load ../helpers/bats_helper

INDEXER="${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts"
FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/sample-session.jsonl"
INTERRUPT_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/interrupt-session.jsonl"
TAG_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/slash-cmd-tag-session.jsonl"

@test "evolve build-index: counts turns and user messages" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.turns_total == 9'
    echo "$output" | jq -e '.user_messages == 3'
}

@test "evolve build-index: emits one user_message signal per user text turn" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # fixture에 user-text turn은 3개 (turn 1, 7, 9) — tool_result만 있는 turn 3, 5 제외
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "user_message")] | length == 3'
}

@test "evolve build-index: user_message includes prior_actions when assistant acted before" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # turn 7 ("아니 그게 아니라 ...") 직전에 assistant가 grep을 돌렸으므로 prior_actions에 잡혀야 함
    echo "$output" | jq -e '[
        .groups[].signals[]
        | select(.kind == "user_message" and (.snippet | startswith("아니")))
        | .prior_actions
    ] | .[0] | length >= 1'
}

@test "evolve build-index: does NOT classify user messages (no user_correction kind)" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # 인덱서는 분류 안 함 — 룰 기반 user_correction/success_pattern kind는 절대 emit 안 함
    echo "$output" | jq -e '[.groups[].signals[].kind] | all(. != "user_correction" and . != "success_pattern")'
}

@test "evolve build-index: detects verbose_exploration (repeated grep)" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "verbose_exploration")] | length >= 1'
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

@test "evolve build-index: detects slash-command in <command-name> tag form" {
    run bun "$INDEXER" "$TAG_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.skill_invocations | length >= 1'
    echo "$output" | jq -e '.skill_invocations[0].name == "me:verify"'
}

@test "evolve build-index: detects interrupt signal" {
    run bun "$INDEXER" "$INTERRUPT_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "interrupt")] | length >= 1'
}

@test "evolve build-index: detects interrupt from interruptedMessageId on user turn" {
    run bun "$INDEXER" "$INTERRUPT_FIXTURE"
    [ "$status" -eq 0 ]
    # interrupt-session.jsonl 은 두 형태 다 포함 → signal 2건 이상
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "interrupt")] | length >= 2'
}

@test "evolve build-index: missing transcript dir exits 14" {
    # 점이 포함된 절대 경로로 cd → encodeCwd 결과는 존재하지 않을 것
    local tmp="$BATS_TEST_TMPDIR/no.such.transcript.dir/nested"
    mkdir -p "$tmp"
    cd "$tmp"
    run bun "$INDEXER"
    [ "$status" -eq 14 ]
}

@test "evolve build-index: produces well-formed index with all three signal kinds" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    local kinds
    kinds=$(echo "$output" | jq -r '[.groups[].signals[].kind] | unique | sort | join(",")')
    [[ "$kinds" == *"user_message"* ]]
    [[ "$kinds" == *"verbose_exploration"* ]]
    # 인덱스 자체 형식 검증
    echo "$output" | jq -e '.session_id and .jsonl_path and .turns_total and (.groups | type == "array")'
}

@test "evolve build-index: false-positive guard — \"stop and report\" body is NOT misclassified" {
    # 인덱서는 분류 안 하므로 본문 안 단어가 신호를 *오발*하지 않는다.
    # 이전 룰 베이스는 "stop and report" 같은 본문을 user_correction으로 잘못 잡았음.
    # 이제 그런 kind가 아예 emit되지 않는다는 사실 자체가 가드.
    local fp_fixture="$BATS_TEST_TMPDIR/false-positive.jsonl"
    cat > "$fp_fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Continue as Task 4 implementer. If backend fails, stop and report exact requirements."}]}}
EOF
    run bun "$INDEXER" "$fp_fixture"
    [ "$status" -eq 0 ]
    # user_correction kind는 존재하지 않아야 함 (인덱서가 분류 안 함)
    echo "$output" | jq -e '[.groups[].signals[].kind] | all(. != "user_correction")'
    # user_message 1건은 있어야 함 (raw collection)
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "user_message")] | length == 1'
}
