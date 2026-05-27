#!/usr/bin/env bats
# build-index.ts 단위 테스트
#
# 인덱서는 결정적 메타데이터만 추출한다. user 발화 분류 (정정/긍정/잡담)는
# Phase 1 LLM이 책임지므로 여기서는 raw events 시계열만 검증.

bats_require_minimum_version 1.5.0
load ../helpers/bats_helper

INDEXER="${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts"
FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/sample-session.jsonl"
INTERRUPT_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/interrupt-session.jsonl"
TAG_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/slash-cmd-tag-session.jsonl"
RICH_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/rich-signals-session.jsonl"

@test "evolve build-index: counts turns" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.turns == 9'
}

@test "evolve build-index: events array is sorted by turn" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # events[].t 가 비감소(non-decreasing) 순서인지 확인
    echo "$output" | jq -e '
      .events as $ev
      | ([range(0; ($ev | length) - 1)] | all(. as $i | $ev[$i].t <= $ev[$i+1].t))
    '
}

@test "evolve build-index: emits user events with prior actions" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # turn 7 의 user 발화 ("아니 그게 아니라 ...") — 직전 assistant가 grep을 돌렸으므로 prior 비어있지 않음
    echo "$output" | jq -e '
      [.events[] | select(.kind == "user" and (.text | startswith("아니")))] | .[0].prior | length >= 1
    '
}

@test "evolve build-index: does NOT classify user messages (no semantic kinds)" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # 인덱서는 분류 안 함 — user_correction/success_pattern 같은 kind는 절대 emit 안 함
    echo "$output" | jq -e '
      [.events[].kind] | all(. as $k | ["user","skill","interrupt","error","agent","large_out","repeat"] | index($k) != null)
    '
}

@test "evolve build-index: detects repeat (Bash prefix 3x+)" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "repeat")] | length >= 1'
}

@test "evolve build-index: output has only summary + events fields" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    # top-level keys: session_id, session_title?, turns, summary, events
    echo "$output" | jq -e '(keys - ["session_id","session_title","turns","summary","events"]) == []'
}

@test "evolve build-index: summary has headline, clusters, signal_positions" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.summary.headline | type == "string"'
    echo "$output" | jq -e '.summary.clusters | type == "array"'
    echo "$output" | jq -e '.summary.signal_positions | type == "object"'
}

@test "evolve build-index: detects slash-command in <command-name> tag form" {
    run bun "$INDEXER" "$TAG_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "skill")] | length >= 1'
    echo "$output" | jq -e '[.events[] | select(.kind == "skill")][0].name == "me:verify"'
}

@test "evolve build-index: detects interrupt events" {
    run bun "$INDEXER" "$INTERRUPT_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "interrupt")] | length >= 2'
}

@test "evolve build-index: interrupt events carry by field (user or assistant)" {
    run bun "$INDEXER" "$INTERRUPT_FIXTURE"
    [ "$status" -eq 0 ]
    # 두 형태 다 포함된 fixture: user 한 번, assistant 한 번
    echo "$output" | jq -e '[.events[] | select(.kind == "interrupt") | .by] | unique | sort == ["assistant","user"]'
}

@test "evolve build-index: missing transcript dir exits 14" {
    local tmp="$BATS_TEST_TMPDIR/no.such.transcript.dir/nested"
    mkdir -p "$tmp"
    cd "$tmp"
    run bun "$INDEXER"
    [ "$status" -eq 14 ]
}

@test "evolve build-index: extracts session_title from ai-title line" {
    run bun "$INDEXER" "$RICH_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_title == "Test session for rich signals"'
}

@test "evolve build-index: detects error event" {
    run bun "$INDEXER" "$RICH_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "error")] | length >= 1'
}

@test "evolve build-index: detects agent event with subagent type and model" {
    run bun "$INDEXER" "$RICH_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '
      [.events[] | select(.kind == "agent")] as $a
      | ($a | length >= 1)
      and ($a[0].desc == "helper sub-task")
      and ($a[0].sub == "general-purpose")
    '
}

@test "evolve build-index: detects large_out event above 10KB" {
    run bun "$INDEXER" "$RICH_FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '
      [.events[] | select(.kind == "large_out")] as $l
      | ($l | length >= 1) and ($l[0].bytes > 10240)
    '
}

@test "evolve build-index: signal_positions kinds appear in events" {
    run bun "$INDEXER" "$RICH_FIXTURE"
    [ "$status" -eq 0 ]
    # 각 signal_positions 키는 실제 events 의 kind 와 일치해야 함
    echo "$output" | jq -e '
      (.summary.signal_positions | keys) as $sk
      | ([.events[].kind] | unique) as $ek
      | ($sk | all(. as $k | $ek | index($k) != null))
    '
}

@test "evolve build-index: false-positive guard — body words do NOT trigger semantic kinds" {
    local fp_fixture="$BATS_TEST_TMPDIR/false-positive.jsonl"
    cat > "$fp_fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Continue as Task 4 implementer. If backend fails, stop and report exact requirements."}]}}
EOF
    run bun "$INDEXER" "$fp_fixture"
    [ "$status" -eq 0 ]
    # user event 1건, 분류 kind 일체 없음
    echo "$output" | jq -e '[.events[] | select(.kind == "user")] | length == 1'
    echo "$output" | jq -e '[.events[].kind] | all(. as $k | ["user","skill","interrupt","error","agent","large_out","repeat"] | index($k) != null)'
}
