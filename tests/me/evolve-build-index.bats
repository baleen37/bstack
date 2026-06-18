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
SKILL_INVOCATION_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/skill-invocation-session.jsonl"

# 트랜스크립트 스캔을 라이브 ~/.claude/projects 가 아닌 격리된 임시 디렉터리로 돌린다.
# 이게 없으면 --skill/--recent 가 실행 중인 현재 세션까지 끌어와 결과가 비결정적이 된다
# (특히 --skill … --recent 1 은 전역 newest 세션 하나만 남겨 fixture를 라이브 세션이 가려버린다).
# cwd 기반 탐지 테스트도 같은 인코딩(transcriptProjectDir)을 쓰므로 EVOLVE_PROJECTS_DIR 하위에
# 동일하게 <encoded-cwd> 디렉터리를 만들면 그대로 동작한다.
setup() {
    export EVOLVE_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    mkdir -p "$EVOLVE_PROJECTS_DIR"
}

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
      [.events[].kind] | all(. as $k | ["user","skill","interrupt","error","agent","repeat"] | index($k) != null)
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

@test "evolve build-index: summary has headline and clusters" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.summary.headline | type == "string"'
    echo "$output" | jq -e '.summary.clusters | type == "array"'
    # signal_positions intentionally removed — clusters + events[] cover its role
    echo "$output" | jq -e '.summary | has("signal_positions") | not'
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

@test "evolve build-index: large_out event kind is no longer emitted" {
    run bun "$INDEXER" "$RICH_FIXTURE"
    [ "$status" -eq 0 ]
    # large_out was removed because Phase 1's mapping table never consumed it.
    echo "$output" | jq -e '[.events[] | select(.kind == "large_out")] | length == 0'
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
    echo "$output" | jq -e '[.events[].kind] | all(. as $k | ["user","skill","interrupt","error","agent","repeat"] | index($k) != null)'
}

@test "evolve build-index: harness-injected <task-notification> is not a user event" {
    local tn_fixture="$BATS_TEST_TMPDIR/task-notification.jsonl"
    cat > "$tn_fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"real user message"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<task-notification>\n<task-id>b51bvqj0n</task-id>\n<summary>Monitor event</summary>\n</task-notification>"}]}}
EOF
    run bun "$INDEXER" "$tn_fixture"
    [ "$status" -eq 0 ]
    # 진짜 user 발화 1건만 잡히고, <task-notification> 주입 텍스트는 제외된다
    echo "$output" | jq -e '[.events[] | select(.kind == "user")] | length == 1'
    echo "$output" | jq -e '[.events[] | select(.kind == "user")][0].text == "real user message"'
}

@test "evolve build-index: harness-injected context markers are not user events" {
    local context_fixture="$BATS_TEST_TMPDIR/context-markers.jsonl"
    cat > "$context_fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"real user message"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<system-reminder>\nInjected context\n</system-reminder>"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<ide-context>\nOpen files and diagnostics\n</ide-context>"}]}}
EOF
    run bun "$INDEXER" "$context_fixture"
    [ "$status" -eq 0 ]
    # 진짜 user 발화 1건만 잡히고, context marker 주입 텍스트는 제외된다
    echo "$output" | jq -e '[.events[] | select(.kind == "user")] | length == 1'
    echo "$output" | jq -e '[.events[] | select(.kind == "user")][0].text == "real user message"'
}

@test "evolve build-index: --recent and --session together exit 2" {
    run bun "$INDEXER" --recent --session abc
    [ "$status" -eq 2 ]
}

@test "evolve build-index: --recent with positional path exits 2" {
    run bun "$INDEXER" --recent "$FIXTURE"
    [ "$status" -eq 2 ]
}

@test "evolve build-index: --recent single fixture surfaces invoked skill in skills[]" {
    # 임시 프로젝트 디렉터리에 fixture를 단일 세션으로 배치하고 cwd 기반 자동탐지로 --recent 실행
    local proj="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$proj"
    cd "$proj"
    # process.cwd()는 심볼릭 링크를 해제한 실제 경로를 반환하므로 pwd -P 사용
    local real_proj
    real_proj="$(pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    cp "$SKILL_INVOCATION_FIXTURE" "$pdir/sess1.jsonl"
    run bun "$INDEXER" --recent 5
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.mode == "recent"'
    echo "$output" | jq -e '[.skills[] | select(.name == "qa")] | length == 1'
}

@test "evolve build-index: identical body → stale:false (version-agnostic)" {
    local skilldir="$BATS_TEST_TMPDIR/skills/demo"
    mkdir -p "$skilldir"
    # disk has frontmatter; injected body will NOT have frontmatter — bodies otherwise identical
    printf -- '---\nname: demo\ndescription: d\n---\n# demo body\n\nidentical line.\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/proj1"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    # printf expands \n to real newlines so jq --arg receives actual multiline text
    local text; text="$(printf 'Base directory for this skill: %s\n\n# demo body\n\nidentical line.\n' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"demo"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"t1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "demo")][0].stale == false'
}

@test "evolve build-index: CRLF injected body matches LF disk body for stale" {
    local skilldir="$BATS_TEST_TMPDIR/skills/crlfskill"
    mkdir -p "$skilldir"
    printf -- '# crlfskill body\n\nsame line.\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/crlfproj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local text; text="$(printf 'Base directory for this skill: %s\r\n\r\n# crlfskill body\r\n\r\nsame line.\r\n' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"c1","name":"Skill","input":{"skill":"crlfskill"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"c1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "crlfskill")][0].stale == false'
}

@test "evolve build-index: CR-only injected body matches LF disk body for stale" {
    local skilldir="$BATS_TEST_TMPDIR/skills/crskill"
    mkdir -p "$skilldir"
    printf -- '# crskill body\n\nsame line.\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/crproj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local text; text="$(printf 'Base directory for this skill: %s\r\r# crskill body\r\rsame line.\r' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"c1","name":"Skill","input":{"skill":"crskill"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"c1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "crskill")][0].stale == false'
}

@test "evolve build-index: changed body → stale:true (dropped, no events)" {
    local skilldir="$BATS_TEST_TMPDIR/skills/demo2"
    mkdir -p "$skilldir"
    printf -- '---\nname: demo2\n---\n# demo body\n\nCHANGED ON DISK.\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/proj2"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# demo body\n\nOLD VERSION AT INVOCATION.\n' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"demo2"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"t1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].stale == true'
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].drop_reason == "stale"'
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].signal == "dropped (stale)"'
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].dropped == true'
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].events | length == 0'
}

@test "evolve build-index: missing disk SKILL.md → stale:true" {
    local proj="$BATS_TEST_TMPDIR/proj3"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local ghost="$BATS_TEST_TMPDIR/skills/ghost"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# ghost body\n' "$ghost")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"ghost"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"t1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "ghost")][0].stale == true'
    echo "$output" | jq -e '[.skills[] | select(.name == "ghost")][0].drop_reason == "missing_current_body"'
    echo "$output" | jq -e '[.skills[] | select(.name == "ghost")][0].dropped == true'
    echo "$output" | jq -e '[.skills[] | select(.name == "ghost")][0].events | length == 0'
}

@test "evolve build-index: --recent merges sessions across worktree sibling dirs" {
    # cwd가 worktree 안일 때, base 프로젝트 디렉터리 + base--worktrees-* 형제 디렉터리의
    # 세션을 모두 합쳐 모은다. base 디렉터리에 skillA, worktree cwd에 skillB 세션을 둔다.
    local base="$BATS_TEST_TMPDIR/myproj"
    local wt="$base/.worktrees/wt1"
    mkdir -p "$wt"
    cd "$wt"
    local real_wt; real_wt="$(pwd -P)"
    local real_base; real_base="$(cd "$base" && pwd -P)"
    local base_pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_base" | sed 's/[/.]/-/g')"
    local wt_pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_wt" | sed 's/[/.]/-/g')"
    mkdir -p "$base_pdir" "$wt_pdir"

    # base 디렉터리 세션: skillA 호출
    local ta; ta="$(printf 'Base directory for this skill: %s\n\n# a\n' "$BATS_TEST_TMPDIR/skills/skillA")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"a1","name":"Skill","input":{"skill":"skillA"}}]}}' -n > "$base_pdir/sa.jsonl"
    jq -c --arg t "$ta" '{"type":"user","isMeta":true,"sourceToolUseID":"a1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$base_pdir/sa.jsonl"

    # worktree cwd 세션: skillB 호출
    local tb; tb="$(printf 'Base directory for this skill: %s\n\n# b\n' "$BATS_TEST_TMPDIR/skills/skillB")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"b1","name":"Skill","input":{"skill":"skillB"}}]}}' -n > "$wt_pdir/sb.jsonl"
    jq -c --arg t "$tb" '{"type":"user","isMeta":true,"sourceToolUseID":"b1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$wt_pdir/sb.jsonl"

    run bun "$INDEXER" --recent 10
    rm -rf "$base_pdir" "$wt_pdir"
    [ "$status" -eq 0 ]
    # 두 worktree의 세션이 모두 모여 session_count == 2
    echo "$output" | jq -e '.session_count == 2'
    echo "$output" | jq -e '[.skills[] | select(.name == "skillA")] | length == 1'
    echo "$output" | jq -e '[.skills[] | select(.name == "skillB")] | length == 1'
}

@test "evolve build-index: --recent skill carries a signal summary with kind counts" {
    # skill 호출 + interrupt(assistant) 가 있는 세션 → signal 문자열에 interrupt가 집계된다.
    local proj="$BATS_TEST_TMPDIR/sigproj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local skilldir="$BATS_TEST_TMPDIR/skills/sig"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# sig body\n' "$skilldir")"
    # 1) skill 호출  2) 주입 본문  3) interrupt 마커가 붙은 assistant turn
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"s1","name":"Skill","input":{"skill":"sig"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"s1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"
    jq -c '{"type":"assistant","message":{"role":"assistant","stop_reason":"interrupted","content":[{"type":"text","text":"stopped"}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    # signal 필드가 문자열로 존재하고, interrupt가 집계되어 있다 (skill은 dropped일 수 있으나
    # 이 세션은 skilldir에 디스크 SKILL.md가 없으므로 dropped → signal=="dropped (missing_current_body)").
    # dropped 케이스의 signal 표기를 검증.
    echo "$output" | jq -e '[.skills[] | select(.name == "sig")][0].signal | type == "string"'
    echo "$output" | jq -e '[.skills[] | select(.name == "sig")][0].signal == "dropped (missing_current_body)"'
}

@test "evolve build-index: --recent live skill signal counts interrupt/error/repeat first" {
    # 디스크 SKILL.md를 호출 본문과 동일하게 두어 NOT stale → events 보존 → signal에 kind 카운트.
    local skilldir="$BATS_TEST_TMPDIR/skills/live"
    mkdir -p "$skilldir"
    printf -- '# live body\n\nsame.\n' > "$skilldir/SKILL.md"
    local proj="$BATS_TEST_TMPDIR/liveproj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# live body\n\nsame.\n' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"l1","name":"Skill","input":{"skill":"live"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"l1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"
    jq -c '{"type":"assistant","message":{"role":"assistant","stop_reason":"interrupted","content":[{"type":"text","text":"x"}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "live")][0].dropped == false'
    # 보존된 skill의 signal은 kind 카운트 문자열이며 interrupt를 포함한다
    echo "$output" | jq -e '[.skills[] | select(.name == "live")][0].signal | test("interrupt")'
}

@test "evolve build-index: observed_bodies show versions and keep current-body events only" {
    local repo="$BATS_TEST_TMPDIR/observed-repo"
    mkdir -p "$repo/plugins/me/skills/observed"
    printf -- '# observed body\n\nsame.\n' > "$repo/plugins/me/skills/observed/SKILL.md"
    cd "$repo"
    local real_repo; real_repo="$(pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_repo" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"

    local current18; current18="$(printf 'Base directory for this skill: %s\n\n# observed body\n\nsame.\n' "$BATS_TEST_TMPDIR/cache/bstack/bstack/17.18.0/skills/observed")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"o1","name":"Skill","input":{"skill":"observed"}}]}}' -n > "$pdir/current18.jsonl"
    jq -c --arg t "$current18" '{"type":"user","isMeta":true,"sourceToolUseID":"o1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/current18.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"current user signal"}]}}' -n >> "$pdir/current18.jsonl"

    local current19; current19="$(printf 'Base directory for this skill: %s\n\n# observed body\n\nsame.\n' "$BATS_TEST_TMPDIR/cache/bstack/bstack/17.19.1/skills/observed")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"o2","name":"Skill","input":{"skill":"observed"}}]}}' -n > "$pdir/current19.jsonl"
    jq -c --arg t "$current19" '{"type":"user","isMeta":true,"sourceToolUseID":"o2","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/current19.jsonl"

    local old17; old17="$(printf 'Base directory for this skill: %s\n\n# observed body\n\nold.\n' "$BATS_TEST_TMPDIR/cache/bstack/bstack/17.17.0/skills/observed")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"o3","name":"Skill","input":{"skill":"observed"}}]}}' -n > "$pdir/old17.jsonl"
    jq -c --arg t "$old17" '{"type":"user","isMeta":true,"sourceToolUseID":"o3","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/old17.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"old user signal"}]}}' -n >> "$pdir/old17.jsonl"

    run bun "$INDEXER" --recent 10
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].dropped == false'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].observed_bodies | length == 2'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].observed_bodies[] | select(.current == true) | .versions == ["17.18.0","17.19.1"]'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0].observed_bodies[] | select(.current == false) | .versions == ["17.17.0"]'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0] | .current_hash == (.observed_bodies[] | select(.current == true) | .hash)'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0] | .events | map(select(.text == "current user signal")) | length == 1'
    echo "$output" | jq -e '[.skills[] | select(.name == "observed")][0] | .events | map(select(.text == "old user signal")) | length == 0'
}

@test "evolve build-index: cache-only keeps newest baseDir for observed_bodies" {
    local cache_new="$BATS_TEST_TMPDIR/cache/bstack/bstack/17.19.1/skills/cached"
    local cache_old="$BATS_TEST_TMPDIR/cache/bstack/bstack/17.17.0/skills/cached"
    mkdir -p "$cache_new" "$cache_old"
    printf -- '# cached body\n\nnew.\n' > "$cache_new/SKILL.md"
    printf -- '# cached body\n\nold.\n' > "$cache_old/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/cache-only-proj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_cache_new; real_cache_new="$(cd "$cache_new" && pwd -P)"
    local real_cache_old; real_cache_old="$(cd "$cache_old" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"

    local old_text; old_text="$(printf 'Base directory for this skill: %s\n\n# cached body\n\nold.\n' "$real_cache_old")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"c1","name":"Skill","input":{"skill":"cached"}}]}}' -n > "$pdir/old.jsonl"
    jq -c --arg t "$old_text" '{"type":"user","isMeta":true,"sourceToolUseID":"c1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/old.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"old signal"}]}}' -n >> "$pdir/old.jsonl"

    local new_text; new_text="$(printf 'Base directory for this skill: %s\n\n# cached body\n\nnew.\n' "$real_cache_new")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"c2","name":"Skill","input":{"skill":"cached"}}]}}' -n > "$pdir/new.jsonl"
    jq -c --arg t "$new_text" '{"type":"user","isMeta":true,"sourceToolUseID":"c2","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/new.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"new signal"}]}}' -n >> "$pdir/new.jsonl"
    touch -t 202001010101 "$pdir/old.jsonl"
    touch -t 202001010102 "$pdir/new.jsonl"

    run bun "$INDEXER" --recent 10
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "cached")][0].dropped == false'
    echo "$output" | jq -e '[.skills[] | select(.name == "cached")][0].observed_bodies[] | select(.current == true) | .versions == ["17.19.1"]'
    echo "$output" | jq -e '[.skills[] | select(.name == "cached")][0].observed_bodies[] | select(.current == false) | .versions == ["17.17.0"]'
    echo "$output" | jq -e '[.skills[] | select(.name == "cached")][0] | .events | map(select(.text == "new signal")) | length == 1'
    echo "$output" | jq -e '[.skills[] | select(.name == "cached")][0] | .events | map(select(.text == "old signal")) | length == 0'
}

@test "evolve build-index: current body with no events is not stale" {
    local skilldir="$BATS_TEST_TMPDIR/skills/noevents"
    mkdir -p "$skilldir"
    printf -- '# noevents body\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/noevents-proj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# noevents body\n' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"n1","name":"Skill","input":{"skill":"noevents"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"n1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "noevents")][0].stale == false'
    echo "$output" | jq -e '[.skills[] | select(.name == "noevents")][0].events | length == 0'
}

@test "evolve build-index: --recent maps cache skill to editable repo_path and uses it for stale" {
    # cwd repo(=plugins/ 보유)에 같은 이름 skill 소스를 두면, transcript가 캐시 경로를 가리켜도
    # repo_path로 매핑되고 stale 비교를 repo 본문 기준으로 한다.
    local repo="$BATS_TEST_TMPDIR/myrepo"
    mkdir -p "$repo/plugins/me/skills/mapme"
    # repo 소스(편집 대상): frontmatter + 본문
    printf -- '---\nname: mapme\n---\n# mapme body\n\nrepo content.\n' > "$repo/plugins/me/skills/mapme/SKILL.md"
    cd "$repo"
    local real_repo; real_repo="$(pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_repo" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    # transcript는 캐시 경로(존재하지 않는 디렉터리)를 가리키지만 본문은 repo 본문과 동일
    local cachedir="$BATS_TEST_TMPDIR/cache/mapme"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# mapme body\n\nrepo content.\n' "$cachedir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"m1","name":"Skill","input":{"skill":"mapme"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"m1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    # repo_path가 repo 소스를 가리킨다
    echo "$output" | jq -e '[.skills[] | select(.name == "mapme")][0].repo_path | test("plugins/me/skills/mapme/SKILL.md")'
    echo "$output" | jq -e '[.skills[] | select(.name == "mapme")][0].skill_path | test("/cache/mapme/SKILL.md$")'
    # 캐시 디렉터리는 디스크에 없지만(null이 아니라) repo 본문으로 비교해 stale:false
    echo "$output" | jq -e '[.skills[] | select(.name == "mapme")][0].stale == false'
}

@test "evolve build-index: --recent ignores trailing ARGUMENTS block in stale comparison" {
    # 슬래시 커맨드를 인자와 함께 호출하면 주입 본문 끝에 "ARGUMENTS: …" 블록이 붙는다.
    # 이는 SKILL.md 본문이 아니므로 stale 비교에서 무시되어야 한다 (본문 동일 → stale:false).
    local skilldir="$BATS_TEST_TMPDIR/skills/argskill"
    mkdir -p "$skilldir"
    printf -- '# argskill body\n\nsame.\n' > "$skilldir/SKILL.md"
    local proj="$BATS_TEST_TMPDIR/argproj"
    mkdir -p "$proj"
    cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    # 주입 본문 = Base directory + 동일 본문 + 끝에 ARGUMENTS 블록
    local text; text="$(printf 'Base directory for this skill: %s\n\n# argskill body\n\nsame.\n\n\nARGUMENTS: "some user input here"' "$real_skilldir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"g1","name":"Skill","input":{"skill":"argskill"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"g1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    # ARGUMENTS 꼬리에도 불구하고 본문이 같으므로 stale:false (오판하면 dropped 됨)
    echo "$output" | jq -e '[.skills[] | select(.name == "argskill")][0].stale == false'
}

@test "evolve build-index: --skill collects sessions across project boundaries" {
    # --skill 은 현재 프로젝트가 아니라 ~/.claude/projects 전체에서 그 skill 호출 세션을 모은다.
    # 서로 다른(형제 관계 아닌) 프로젝트 디렉터리 두 곳에 같은 skill 세션을 둔다.
    local skilldir="$BATS_TEST_TMPDIR/skills/findme"
    mkdir -p "$skilldir"
    printf -- '# findme body\n\nbody.\n' > "$skilldir/SKILL.md"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# findme body\n\nbody.\n' "$real_skilldir")"
    # 무관한 두 프로젝트 디렉터리 (worktree 형제 아님)
    local pA="$EVOLVE_PROJECTS_DIR/-tmp-evolve-skilltest-projA-$$"
    local pB="$EVOLVE_PROJECTS_DIR/-tmp-evolve-skilltest-projB-$$"
    mkdir -p "$pA" "$pB"
    for p in "$pA" "$pB"; do
        jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"f1","name":"Skill","input":{"skill":"findme"}}]}}' -n > "$p/s.jsonl"
        jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"f1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/s.jsonl"
    done

    run bun "$INDEXER" --skill findme --recent 2
    rm -rf "$pA" "$pB"
    [ "$status" -eq 0 ]
    # positive --recent N 조합이 허용되고 두 프로젝트의 세션이 모두 모인다
    echo "$output" | jq -e '.session_count == 2'
    # skills[]에는 대상 skill만
    echo "$output" | jq -e '[.skills[].name] | unique == ["findme"]'
}

@test "evolve build-index: --skill accepts user-facing prefixed skill name" {
    # user-facing slash command name(me:evolve)는 Base directory basename(evolve)과 같은 skill로 취급한다.
    local skilldir="$BATS_TEST_TMPDIR/skills/evolve"
    mkdir -p "$skilldir"
    printf -- '# evolve body\n' > "$skilldir/SKILL.md"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# evolve body\n' "$real_skilldir")"
    local p="$EVOLVE_PROJECTS_DIR/-tmp-evolve-skilltest-prefixed-$$"
    mkdir -p "$p"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"e1","name":"Skill","input":{"skill":"me:evolve"}}]}}' -n > "$p/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"e1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/s.jsonl"

    run bun "$INDEXER" --skill me:evolve --recent 1
    rm -rf "$p"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_count == 1'
    echo "$output" | jq -e '[.skills[].name] == ["evolve"]'
}

@test "evolve build-index: --skill exact colon name does not also match basename" {
    # 실제 directory basename이 foo:bar인 skill은 별도 bar skill과 구분되어야 한다.
    local colon_dir="$BATS_TEST_TMPDIR/skills/foo:bar"
    local base_dir="$BATS_TEST_TMPDIR/skills/bar"
    mkdir -p "$colon_dir" "$base_dir"
    printf -- '# foo:bar body\n' > "$colon_dir/SKILL.md"
    printf -- '# bar body\n' > "$base_dir/SKILL.md"
    local real_colon; real_colon="$(cd "$colon_dir" && pwd -P)"
    local real_base; real_base="$(cd "$base_dir" && pwd -P)"
    local colon_text; colon_text="$(printf 'Base directory for this skill: %s\n\n# foo:bar body\n' "$real_colon")"
    local base_text; base_text="$(printf 'Base directory for this skill: %s\n\n# bar body\n' "$real_base")"
    local p="$EVOLVE_PROJECTS_DIR/-tmp-evolve-skilltest-colon-exact-$$"
    mkdir -p "$p"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"c1","name":"Skill","input":{"skill":"foo:bar"}}]}}' -n > "$p/colon.jsonl"
    jq -c --arg t "$colon_text" '{"type":"user","isMeta":true,"sourceToolUseID":"c1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/colon.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<command-name>/foo:bar</command-name>"}]}}' -n >> "$p/colon.jsonl"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"b1","name":"Skill","input":{"skill":"bar"}}]}}' -n > "$p/base.jsonl"
    jq -c --arg t "$base_text" '{"type":"user","isMeta":true,"sourceToolUseID":"b1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/base.jsonl"

    run bun "$INDEXER" --skill foo:bar --recent 10
    rm -rf "$p"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_count == 1'
    echo "$output" | jq -e '[.skills[].name] == ["foo:bar"]'
    echo "$output" | jq -e '[.skills[0].events[] | select(.kind == "skill" and .name == "foo:bar")] | length == 1'
}

@test "evolve build-index: --skill filters to the target skill only" {
    # 같은 세션에 두 skill이 호출돼도 --skill 은 대상 하나만 skills[]에 남긴다.
    local sa="$BATS_TEST_TMPDIR/skills/keep"; mkdir -p "$sa"; printf -- '# keep\n' > "$sa/SKILL.md"
    local sb="$BATS_TEST_TMPDIR/skills/drop"; mkdir -p "$sb"; printf -- '# drop\n' > "$sb/SKILL.md"
    local ra; ra="$(cd "$sa" && pwd -P)"; local rb; rb="$(cd "$sb" && pwd -P)"
    local ta; ta="$(printf 'Base directory for this skill: %s\n\n# keep\n' "$ra")"
    local tb; tb="$(printf 'Base directory for this skill: %s\n\n# drop\n' "$rb")"
    local p="$EVOLVE_PROJECTS_DIR/-tmp-evolve-skilltest-filter-$$"
    mkdir -p "$p"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"k1","name":"Skill","input":{"skill":"keep"}}]}}' -n > "$p/s.jsonl"
    jq -c --arg t "$ta" '{"type":"user","isMeta":true,"sourceToolUseID":"k1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/s.jsonl"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"d1","name":"Skill","input":{"skill":"drop"}}]}}' -n >> "$p/s.jsonl"
    jq -c --arg t "$tb" '{"type":"user","isMeta":true,"sourceToolUseID":"d1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/s.jsonl"

    run bun "$INDEXER" --skill keep
    rm -rf "$p"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[].name] == ["keep"]'
}

@test "evolve build-index: --skill with no matching sessions exits 14" {
    run bun "$INDEXER" --skill __no_such_skill_xyz__
    [ "$status" -eq 14 ]
}

@test "evolve build-index: --skill empty name exits 2" {
    run bun "$INDEXER" --skill ""
    [ "$status" -eq 2 ]
}

@test "evolve build-index: --skill and --session together exit 2" {
    run bun "$INDEXER" --skill foo --session abc
    [ "$status" -eq 2 ]
}

@test "evolve build-index: raw multi-skill shorthand is rejected clearly" {
    run bun "$INDEXER" --skill handoff pickup
    [ "$status" -eq 2 ]
    [[ "$output" == *"do not combine --skill with positional arguments"* ]]
}

@test "evolve build-index: --dry-run is rejected by indexer" {
    run bun "$INDEXER" --dry-run
    [ "$status" -eq 2 ]
}

@test "evolve build-index: --help prints usage" {
    run bun "$INDEXER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: bun build-index.ts"* ]]
    [[ "$output" == *"--cwd <dir>"* ]]
    [[ "$output" == *"--dry-run is handled by the /me:evolve skill"* ]]
}

@test "evolve build-index: --session without value exits 2" {
    run bun "$INDEXER" --session
    [ "$status" -eq 2 ]
}

@test "evolve build-index: --session rejects flag as value" {
    run bun "$INDEXER" --session --recent
    [ "$status" -eq 2 ]
    [[ "$output" == *"--session requires a session id"* ]]
}

@test "evolve build-index: --skill without value exits 2" {
    run bun "$INDEXER" --skill
    [ "$status" -eq 2 ]
}

@test "evolve build-index: --skill rejects flag as value" {
    run bun "$INDEXER" --skill --recent
    [ "$status" -eq 2 ]
    [[ "$output" == *"--skill requires a skill name"* ]]
}

@test "evolve build-index: --recent invalid value exits 2 with clear error" {
    run bun "$INDEXER" --recent 0
    [ "$status" -eq 2 ]
    [[ "$output" == *"--recent requires a positive integer"* ]]

    run bun "$INDEXER" --recent -1
    [ "$status" -eq 2 ]
    [[ "$output" == *"--recent requires a positive integer"* ]]

    run bun "$INDEXER" --recent abc
    [ "$status" -eq 2 ]
    [[ "$output" == *"--recent requires a positive integer"* ]]
}

@test "evolve build-index: --recent rejects transcript paths with clear error" {
    run bun "$INDEXER" --recent fixtures/chosen.jsonl
    [ "$status" -eq 2 ]
    [[ "$output" == *"--recent cannot be combined with a transcript path"* ]]
}

@test "evolve build-index: --skill --recent invalid value exits 2 with clear error" {
    run bun "$INDEXER" --skill evolve --recent nope
    [ "$status" -eq 2 ]
    [[ "$output" == *"--recent requires a positive integer"* ]]
}

@test "evolve build-index: --skill summary headline reflects filtered skills" {
    local sa="$BATS_TEST_TMPDIR/skills/sumkeep"; mkdir -p "$sa"; printf -- '# sumkeep\n' > "$sa/SKILL.md"
    local sb="$BATS_TEST_TMPDIR/skills/sumdrop"; mkdir -p "$sb"; printf -- '# sumdrop changed\n' > "$sb/SKILL.md"
    local ra; ra="$(cd "$sa" && pwd -P)"; local rb; rb="$(cd "$sb" && pwd -P)"
    local ta; ta="$(printf 'Base directory for this skill: %s\n\n# sumkeep\n' "$ra")"
    local tb; tb="$(printf 'Base directory for this skill: %s\n\n# sumdrop\n' "$rb")"
    local p="$EVOLVE_PROJECTS_DIR/-tmp-evolve-skilltest-summary-$$"
    mkdir -p "$p"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"k1","name":"Skill","input":{"skill":"sumkeep"}}]}}' -n > "$p/s.jsonl"
    jq -c --arg t "$ta" '{"type":"user","isMeta":true,"sourceToolUseID":"k1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/s.jsonl"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"d1","name":"Skill","input":{"skill":"sumdrop"}}]}}' -n >> "$p/s.jsonl"
    jq -c --arg t "$tb" '{"type":"user","isMeta":true,"sourceToolUseID":"d1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$p/s.jsonl"

    run bun "$INDEXER" --skill sumkeep
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[].name] == ["sumkeep"]'
    echo "$output" | jq -e '.summary.headline | test("1 skills · 0 dropped")'

    run bun "$INDEXER" --skill sumdrop
    rm -rf "$p"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[].name] == ["sumdrop"]'
    echo "$output" | jq -e '.summary.headline | test("1 skills · 1 dropped: 1 stale")'
}

@test "evolve build-index: duplicate singleton flags exit 2" {
    run bun "$INDEXER" --recent 2 --recent 1
    [ "$status" -eq 2 ]
    [[ "$output" == *"--recent can only be specified once"* ]]

    run bun "$INDEXER" --session a --session b
    [ "$status" -eq 2 ]
    [[ "$output" == *"--session can only be specified once"* ]]

    run bun "$INDEXER" --skill a --skill b
    [ "$status" -eq 2 ]
    [[ "$output" == *"--skill can only be specified once"* ]]

    run bun "$INDEXER" --cwd /tmp --cwd /tmp
    [ "$status" -eq 2 ]
    [[ "$output" == *"--cwd can only be specified once"* ]]
}

@test "evolve build-index: --cwd without value exits 2" {
    run bun "$INDEXER" --cwd
    [ "$status" -eq 2 ]
    [[ "$output" == *"--cwd requires a directory"* ]]
}

@test "evolve build-index: --cwd rejects file path" {
    local f="$BATS_TEST_TMPDIR/not-a-dir"
    touch "$f"
    run bun "$INDEXER" --cwd "$f"
    [ "$status" -eq 2 ]
    [[ "$output" == *"--cwd expects a directory:"* ]]
}

@test "evolve build-index: --cwd cannot combine with positional path" {
    run bun "$INDEXER" --cwd /tmp "$FIXTURE"
    [ "$status" -eq 2 ]
    [[ "$output" == *"--cwd cannot be combined with a transcript path"* ]]
}

@test "evolve build-index: --session rejects path-like values" {
    run bun "$INDEXER" --session chosen.jsonl
    [ "$status" -eq 2 ]
    [[ "$output" == *"--session expects a transcript session id without .jsonl or path separators"* ]]

    run bun "$INDEXER" --session fixtures/chosen
    [ "$status" -eq 2 ]
    [[ "$output" == *"--session expects a transcript session id without .jsonl or path separators"* ]]

    run bun "$INDEXER" --session /tmp/chosen.jsonl
    [ "$status" -eq 2 ]
    [[ "$output" == *"--session expects a transcript session id without .jsonl or path separators"* ]]
}

@test "evolve build-index: --session and positional path together exit 2" {
    run bun "$INDEXER" --session chosen "$FIXTURE"
    [ "$status" -eq 2 ]
    [[ "$output" == *"--session cannot be combined with a transcript path"* ]]
}

@test "evolve build-index: --skill rejects path-like values" {
    run bun "$INDEXER" --skill plugins/me/skills/evolve
    [ "$status" -eq 2 ]
    [[ "$output" == *"--skill expects a skill name, not a path"* ]]

    run bun "$INDEXER" --skill evolve/SKILL.md
    [ "$status" -eq 2 ]
    [[ "$output" == *"--skill expects a skill name, not a path"* ]]
}

@test "evolve build-index: invalid positional transcript paths exit 14 without stack trace" {
    local missing="$BATS_TEST_TMPDIR/missing.jsonl"
    run bun "$INDEXER" "$missing"
    [ "$status" -eq 14 ]
    [[ "$output" == *"transcript file not found:"* ]]
    [[ "$output" != *"ENOENT"* ]]

    local dirpath="$BATS_TEST_TMPDIR/transcript-dir"
    mkdir -p "$dirpath"
    run bun "$INDEXER" "$dirpath"
    [ "$status" -eq 14 ]
    [[ "$output" == *"transcript directory not found:"* ]]
    [[ "$output" != *"EISDIR"* ]]
}

@test "evolve build-index: positional directory resolves that cwd latest transcript" {
    local target="$BATS_TEST_TMPDIR/target-worktree"
    mkdir -p "$target"
    local real_target; real_target="$(cd "$target" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_target" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"target cwd signal"}]}}' -n > "$pdir/old.jsonl"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"newest target signal"}]}}' -n > "$pdir/new.jsonl"
    touch -t 202001010101 "$pdir/old.jsonl"
    touch -t 202001010102 "$pdir/new.jsonl"

    run bun "$INDEXER" "$target"
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_id == "new"'
    echo "$output" | jq -e '.events[0].text == "newest target signal"'
}

@test "evolve build-index: --cwd resolves another cwd latest transcript" {
    local target="$BATS_TEST_TMPDIR/cwd-current-target"
    mkdir -p "$target"
    local real_target; real_target="$(cd "$target" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_target" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"cwd current signal"}]}}' -n > "$pdir/current.jsonl"

    run bun "$INDEXER" --cwd "$target"
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_id == "current"'
    echo "$output" | jq -e '.events[0].text == "cwd current signal"'
}

@test "evolve build-index: --cwd --session resolves session in target cwd" {
    local target="$BATS_TEST_TMPDIR/cwd-session-target"
    mkdir -p "$target"
    local real_target; real_target="$(cd "$target" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_target" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"chosen target session"}]}}' -n > "$pdir/chosen.jsonl"

    run bun "$INDEXER" --cwd "$target" --session chosen
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_id == "chosen"'
    echo "$output" | jq -e '.events[0].text == "chosen target session"'
}

@test "evolve build-index: --cwd --recent uses target cwd worktree group" {
    local base="$BATS_TEST_TMPDIR/cwd-recent"
    local wt="$base/.worktrees/wt1"
    mkdir -p "$wt"
    local real_base; real_base="$(cd "$base" && pwd -P)"
    local real_wt; real_wt="$(cd "$wt" && pwd -P)"
    local base_pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_base" | sed 's/[/.]/-/g')"
    local wt_pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_wt" | sed 's/[/.]/-/g')"
    mkdir -p "$base_pdir" "$wt_pdir"
    local skilldir="$BATS_TEST_TMPDIR/skills/cwdrecent"; mkdir -p "$skilldir"; printf -- '# cwdrecent\n' > "$skilldir/SKILL.md"
    local real_skill; real_skill="$(cd "$skilldir" && pwd -P)"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# cwdrecent\n' "$real_skill")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"a1","name":"Skill","input":{"skill":"cwdrecent"}}]}}' -n > "$base_pdir/a.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"a1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$base_pdir/a.jsonl"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"b1","name":"Skill","input":{"skill":"cwdrecent"}}]}}' -n > "$wt_pdir/b.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"b1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$wt_pdir/b.jsonl"

    run bun "$INDEXER" --cwd "$wt" --recent 10
    rm -rf "$base_pdir" "$wt_pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_count == 2'
    echo "$output" | jq -e '[.skills[].name] == ["cwdrecent"]'
}

@test "evolve build-index: --cwd --skill maps repo_path from target cwd" {
    local repo="$BATS_TEST_TMPDIR/cwd-skill-repo"
    mkdir -p "$repo/plugins/me/skills/cwdskill"
    printf -- '# cwdskill\n' > "$repo/plugins/me/skills/cwdskill/SKILL.md"
    local real_repo; real_repo="$(cd "$repo" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/-tmp-evolve-cwd-skill-$$"
    mkdir -p "$pdir"
    local cachedir="$BATS_TEST_TMPDIR/cache/cwdskill"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# cwdskill\n' "$cachedir")"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"c1","name":"Skill","input":{"skill":"cwdskill"}}]}}' -n > "$pdir/s.jsonl"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"sourceToolUseID":"c1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$pdir/s.jsonl"

    run bun "$INDEXER" --cwd "$repo" --skill cwdskill --recent 1
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "cwdskill")][0].repo_path | test("plugins/me/skills/cwdskill/SKILL.md")'
    echo "$output" | jq -e '[.skills[] | select(.name == "cwdskill")][0].stale == false'
}

@test "evolve build-index: noisy local command markers are not user events" {
    local noise_fixture="$BATS_TEST_TMPDIR/noisy-markers.jsonl"
    cat > "$noise_fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"real user message"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<local-command-stdout>\noutput\n</local-command-stdout>"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<bash-input>pwd</bash-input>"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"<bash-stdout>/tmp</bash-stdout>"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}
EOF
    run bun "$INDEXER" "$noise_fixture"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "user")] | length == 1'
    echo "$output" | jq -e '[.events[] | select(.kind == "user")][0].text == "real user message"'
}

@test "evolve build-index: short approval replies remain user events" {
    local approval_fixture="$BATS_TEST_TMPDIR/approval-markers.jsonl"
    cat > "$approval_fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"ok"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"1"}]}}
EOF
    run bun "$INDEXER" "$approval_fixture"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "user") | .text] == ["ok","1"]'
}

@test "evolve build-index: absolute-path user message is NOT a skill event (P3)" {
    # 사용자가 절대경로로 시작하는 발화를 하면 가짜 skill(name="Users")로 오분류되면 안 됨
    local fixture="$BATS_TEST_TMPDIR/abspath.jsonl"
    cat > "$fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"/Users/jito/dev/foo.ts 를 읽고 고쳐줘"}]}}
EOF
    run bun "$INDEXER" "$fixture"
    [ "$status" -eq 0 ]
    # 가짜 skill 이벤트 없음
    echo "$output" | jq -e '[.events[] | select(.kind == "skill")] | length == 0'
    # 실제 user 발화는 보존됨
    echo "$output" | jq -e '[.events[] | select(.kind == "user")] | length == 1'
}

@test "evolve build-index: real slash command still detected after P3 fix" {
    local fixture="$BATS_TEST_TMPDIR/realslash.jsonl"
    cat > "$fixture" <<'EOF'
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"/me:handoff"}]}}
EOF
    run bun "$INDEXER" "$fixture"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "skill")][0].name == "me:handoff"'
}

@test "evolve build-index: trivial shell prefixes do not produce repeat events (P2)" {
    local fixture="$BATS_TEST_TMPDIR/trivial-repeat.jsonl"
    : > "$fixture"
    # cd 보일러플레이트 5회 — repeat 신호로 잡히면 안 됨
    for i in 1 2 3 4 5; do
      jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"a","name":"Bash","input":{"command":"cd /tmp/work && ls"}}]}}' -n >> "$fixture"
    done
    run bun "$INDEXER" "$fixture"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "repeat")] | length == 0'
}

@test "evolve build-index: meaningful Bash prefix still produces repeat events" {
    local fixture="$BATS_TEST_TMPDIR/real-repeat.jsonl"
    : > "$fixture"
    for i in 1 2 3 4; do
      jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"a","name":"Bash","input":{"command":"bun test foo"}}]}}' -n >> "$fixture"
    done
    run bun "$INDEXER" "$fixture"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.events[] | select(.kind == "repeat")] | length == 1'
}

@test "evolve build-index: prior summarizes Skill tool by skill name not raw JSON (P4)" {
    local fixture="$BATS_TEST_TMPDIR/prior-skill.jsonl"
    : > "$fixture"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"a","name":"Skill","input":{"skill":"superpowers:brainstorming"}}]}}' -n >> "$fixture"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"그게 아니라 다르게 해줘"}]}}' -n >> "$fixture"
    run bun "$INDEXER" "$fixture"
    [ "$status" -eq 0 ]
    # prior에 raw JSON("{\"skill\"...)이 아니라 사람이 읽을 수 있는 요약이 들어가야 함
    echo "$output" | jq -e '[.events[] | select(.kind == "user")][0].prior | any(test("superpowers:brainstorming"))'
    # JSON 중괄호가 전혀 없어야 함 (raw 덤프 금지)
    echo "$output" | jq -e '[.events[] | select(.kind == "user")][0].prior | all(test("[{}]") | not)'
}

@test "evolve build-index: --recent scopes non-skill events to nearest prior skill (DEFECT1)" {
    # 한 세션에서 skillA → error → skillB → error 순서.
    # 첫 error는 skillA에만, 둘째 error는 skillB에만 귀속되어야 한다 (양쪽 복사 금지).
    local skillsroot="$BATS_TEST_TMPDIR/skills"
    mkdir -p "$skillsroot/skilla" "$skillsroot/skillb"
    printf -- '# skilla body\n' > "$skillsroot/skilla/SKILL.md"
    printf -- '# skillb body\n' > "$skillsroot/skillb/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/projdefect1"
    mkdir -p "$proj"; cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local da; da="$(cd "$skillsroot/skilla" && pwd -P)"
    local db; db="$(cd "$skillsroot/skillb" && pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local f="$pdir/s.jsonl"; : > "$f"
    # skillA 호출 + 주입 본문
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"s1","name":"Skill","input":{"skill":"skilla"}}]}}' -n >> "$f"
    jq -c --arg t "$(printf 'Base directory for this skill: %s\n\n# skilla body\n' "$da")" '{"type":"user","isMeta":true,"sourceToolUseID":"s1","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$f"
    # skillA 구간의 error
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"e1","name":"Read","input":{"file_path":"/x"}}]}}' -n >> "$f"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"e1","is_error":true,"content":"error in A"}]}}' -n >> "$f"
    # skillB 호출 + 주입 본문
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"s2","name":"Skill","input":{"skill":"skillb"}}]}}' -n >> "$f"
    jq -c --arg t "$(printf 'Base directory for this skill: %s\n\n# skillb body\n' "$db")" '{"type":"user","isMeta":true,"sourceToolUseID":"s2","message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$f"
    # skillB 구간의 error
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"e2","name":"Read","input":{"file_path":"/y"}}]}}' -n >> "$f"
    jq -c '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"e2","is_error":true,"content":"error in B"}]}}' -n >> "$f"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    # skillA는 error 1개("error in A")만, skillB는 error 1개("error in B")만
    echo "$output" | jq -e '[.skills[] | select(.name=="skilla")][0].events | map(select(.kind=="error")) | length == 1'
    echo "$output" | jq -e '[.skills[] | select(.name=="skilla")][0].events | any(.kind=="error" and (.text | test("error in A")))'
    echo "$output" | jq -e '[.skills[] | select(.name=="skilla")][0].events | any(.kind=="error" and (.text | test("error in B"))) | not'
    echo "$output" | jq -e '[.skills[] | select(.name=="skillb")][0].events | map(select(.kind=="error")) | length == 1'
    echo "$output" | jq -e '[.skills[] | select(.name=="skillb")][0].events | any(.kind=="error" and (.text | test("error in B")))'
}

# ── 하네스 포맷 의존성 골든 테스트 ──
# 인덱서는 공개 스키마가 없는 트랜스크립트 라인 포맷(FMT.*)에 의존한다. 하네스가 그 포맷을
# 바꾸면 프로덕션이 조용히 빈 결과를 내기 전에 이 테스트들이 먼저 깨져 변경을 알린다.

@test "evolve build-index: golden line format wires through FMT fields (single session)" {
    # 단일 세션이 의존하는 FMT 필드를 한 번에 고정: ai-title/aiTitle → session_title,
    # interrupt 마커 두 종류(user interruptedMessageId / assistant stop_reason).
    # (skillInjectionMarker+metaFlag → skill 귀속은 --recent 경로라 DEFECT1/prefixed 테스트가 커버한다.)
    local f="$BATS_TEST_TMPDIR/golden.jsonl"; : > "$f"
    jq -c '{"type":"ai-title","aiTitle":"golden session"}' -n >> "$f"
    jq -c '{"type":"user","message":{"role":"user","content":"work on it"}}' -n >> "$f"
    jq -c '{"type":"user","interruptedMessageId":"x","message":{"role":"user","content":"stop"}}' -n >> "$f"
    jq -c '{"type":"assistant","message":{"role":"assistant","stop_reason":"interrupted","content":[{"type":"text","text":"…"}]}}' -n >> "$f"

    run bun "$INDEXER" "$f"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.session_title == "golden session"'           # FMT.aiTitleType/aiTitleField
    echo "$output" | jq -e '[.events[] | select(.kind=="interrupt" and .by=="user")] | length >= 1'       # FMT.userInterruptField
    echo "$output" | jq -e '[.events[] | select(.kind=="interrupt" and .by=="assistant")] | length >= 1'  # FMT.assistantInterruptStopReason
}

@test "evolve build-index: golden skill injection wires through FMT marker (recent)" {
    # skillInjectionMarker + metaFlag 경로: isMeta user 라인의 "Base directory for this skill:" 본문이
    # skill 호출로 인식되어 --recent 집계의 skills[]에 잡혀야 한다.
    local skilldir="$BATS_TEST_TMPDIR/skills/research"
    mkdir -p "$skilldir"
    printf -- '# research body\n' > "$skilldir/SKILL.md"
    local real_skilldir; real_skilldir="$(cd "$skilldir" && pwd -P)"
    local text; text="$(printf 'Base directory for this skill: %s\n\n# research body\n' "$real_skilldir")"
    local proj="$BATS_TEST_TMPDIR/projgolden"; mkdir -p "$proj"; cd "$proj"
    local real_proj; real_proj="$(pwd -P)"
    local pdir="$EVOLVE_PROJECTS_DIR/$(echo "$real_proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local f="$pdir/s.jsonl"; : > "$f"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"s1","name":"Skill","input":{"skill":"research"}}]}}' -n >> "$f"
    jq -c --arg t "$text" '{"type":"user","isMeta":true,"message":{"role":"user","content":[{"type":"text","text":$t}]}}' -n >> "$f"

    run bun "$INDEXER" --skill research
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[].name] == ["research"]'
}

@test "evolve build-index: health-check warns when format extracts nothing" {
    # turn은 많은데 tool_use·skill 주입이 0 → 포맷이 깨졌을 가능성. stderr 경고로 표면화.
    local f="$BATS_TEST_TMPDIR/broken.jsonl"; : > "$f"
    for i in $(seq 1 12); do
        jq -c --arg n "$i" '{"type":"user","message":{"role":"user","content":("hello "+$n)}}' -n >> "$f"
    done
    bun "$INDEXER" "$f" >/dev/null 2>"$BATS_TEST_TMPDIR/err.txt"
    grep -qF "[evolve] warning" "$BATS_TEST_TMPDIR/err.txt"
    grep -qF "extraction may be silently failing" "$BATS_TEST_TMPDIR/err.txt"
}

@test "evolve build-index: health-check warns on zero parsed turns" {
    # user/assistant 라인이 하나도 없으면 0 turns → 라인 포맷 변경 의심 경고.
    local f="$BATS_TEST_TMPDIR/zero.jsonl"
    jq -c '{"type":"queue-operation","operation":"enqueue"}' -n > "$f"
    bun "$INDEXER" "$f" >/dev/null 2>"$BATS_TEST_TMPDIR/err.txt"
    grep -qF "parsed to 0 turns" "$BATS_TEST_TMPDIR/err.txt"
}

@test "evolve build-index: health-check stays silent on short healthy session" {
    # 짧은 정상 세션(< 10 turns)은 도구가 없어도 경고하지 않는다 — 과잉 경고 금지.
    local f="$BATS_TEST_TMPDIR/short.jsonl"; : > "$f"
    jq -c '{"type":"user","message":{"role":"user","content":"hi"}}' -n >> "$f"
    jq -c '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"hey"}]}}' -n >> "$f"
    bun "$INDEXER" "$f" >/dev/null 2>"$BATS_TEST_TMPDIR/err.txt"
    run grep -F "[evolve] warning" "$BATS_TEST_TMPDIR/err.txt"
    [ "$status" -ne 0 ]
}
