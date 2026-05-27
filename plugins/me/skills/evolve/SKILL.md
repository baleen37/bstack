---
name: evolve
description: Use when asked to "evolve skill", "스킬 개선", "회고", or "analyze this session". Reads the current session's transcript jsonl, extracts user corrections / verbose exploration / success patterns, and proposes patches to SKILL.md / AGENTS.md / CLAUDE.md one at a time with explicit user approval and individual commits.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Agent
---

# /me:evolve — Transcript 기반 Skill·Doc 진화

세션 transcript에서 개선 신호를 추출해 SKILL.md / AGENTS.md / CLAUDE.md에 patch를 제안한다. 한 건씩 사용자 승인 → Edit → 개별 commit.

## When to run

사용자가 명시적으로 호출했을 때만. 자동 트리거 없음.

```
/me:evolve                          현재 세션 회고
/me:evolve --skill me:research      해당 스킬에 집중
/me:evolve --session <id>           특정 세션 ID
/me:evolve --dry-run                제안만, 적용 안 함
```

## What this skill does NOT do

- raw transcript를 메인 에이전트가 직접 읽지 않는다 (컨텍스트 폭발 방지)
- 외부 플러그인 캐시(`~/.claude/plugins/cache/`)는 수정 안 한다 (upstream 제안 파일에만 누적)
- 새 스킬을 만들지 않는다 (`writing-skills` 영역)
- 자동 commit·push 안 한다 (반드시 사용자가 한 건씩 승인)
- 단, 플러그인 레포 자체(`bstack`의 `plugins/`) 안의 SKILL.md는 정상 수정 대상이다. "외부 캐시 차단"은 `~/.claude/plugins/cache/` 경로만 가리킨다.

## Phase 0 — 인덱스 빌드

Phase 0에서 메인 에이전트는 두 가지를 한다:

> **언어 규칙**: 모든 스킬 스크립트는 TypeScript(Bun 런타임)로 작성한다. shell/Python 대안을 제안하지 말 것. 계획 단계, 리뷰 에이전트 제안, 구현 subagent 지시 모두 동일하게 적용.

1. **Dirty tree 가드** — `git status --porcelain`이 비어 있어야 한다. dirty면 "커밋이나 stash 후 다시 실행하세요"라고 알리고 종료.

2. **인덱스 빌드** — `build-index.ts`는 read-only로 transcript 자동 탐지 + 신호 추출 + JSON 출력을 한다.

```bash
bun "${CLAUDE_PLUGIN_ROOT}/skills/evolve/scripts/build-index.ts" [--session <id>] [--skill <name>]
```

종료 코드: `0`=정상, `14`=transcript 또는 project dir을 못 찾음.

stdout JSON을 변수에 캡처. **사용자에게 보여주지 말 것** — 다음 단계 서브에이전트에게만 전달.

`events`가 비어 있거나 `signal_counts`에 user/interrupt/error/repeat가 모두 없으면: "이 세션에서는 개선 신호를 못 찾았어요" 출력 후 종료.

## Phase 1 — 서브에이전트 분석 (Agent)

서브에이전트(`general-purpose`)를 1개 디스패치한다. 인덱서가 user 발화를 분류 없이 raw로 넘기므로 **분류는 서브에이전트의 일**이다.

> **금기**: `build-index.ts`에 룰 기반 분류 로직(정규식, 키워드 매칭)을 추가하지 말 것. 본문에 우연히 등장한 단어로 false positive가 나서 폐기한 패턴이다. 분류는 무조건 LLM이.

프롬프트에 다음을 모두 포함:

1. spec 경로: `docs/superpowers/specs/2026-05-27-evolve-skill-design.md`
2. Phase 0에서 받은 인덱스 JSON 전체. **먼저 `summary`를 읽어라** — `headline`(한 줄 상태), `clusters`(같은 kind 인접 turn ≥3회 묶음, `t_range`/`n`/`example_t` 포함), `signal_positions`(kind별 turn 좌표). 이걸로 어느 구간을 깊이 볼지 정한 뒤 `events[]`를 슬라이스해 인과 사슬 분석. 보조: `skill_runs`, `signal_counts`, `tools_top`. summary는 단순 휴리스틱이라 false positive 가능 — 무의미한 cluster는 그냥 넘겨라.
3. **`kind: "user"` 이벤트 분류 작업** — 각각을 다음 중 하나로 라벨 (event의 array index로 참조: e.g. `events[12]`):
   - **correction**: 직전 assistant 행동의 방향을 정정하는 의도
   - **success**: 직전 assistant 행동에 대한 긍정 피드백
   - **directive**: 새 작업 지시 (정정/긍정 아님)
   - **question**: 질의
   - **noise**: 메타·잡담 (분석 가치 없음)

   분류 기준은 *직전 assistant 행동(`event.prior`)과의 관계*이지 단어 자체가 아니다. 예: "stop and report"는 본문 동사라 noise, "stop, that's wrong"는 correction.

4. 후보 파일 매핑 표 (분류 결과 + interrupt/repeat/error 이벤트 함께 보고):

   | 신호 패턴 | 1순위 후보 | 2순위 |
   |---|---|---|
   | correction 다수 → 스킬 미발견 | 해당 SKILL.md (description, 트리거) | 가까운 AGENTS.md |
   | correction → 스킬 invoke 후에도 규칙 위반 | 해당 SKILL.md (본문, Red Flags 섹션) | — |
   | repeat + 결국 X 찾음 | 가까운 AGENTS.md (Key Files) | CLAUDE.md |
   | correction → 프로젝트 룰/관례 위반 | 가까운 CLAUDE.md | AGENTS.md |
   | success → 한 스킬이 잘 작동 | 자주 호출된 SKILL.md (강화) | — |
   | interrupt + 직전 행동 명백히 잘못됨 | 해당 SKILL.md | AGENTS.md |
   | error 반복 → 같은 도구로 실패 | 해당 SKILL.md (사용법) | CLAUDE.md |

   **"가까운" 해석**: "해당 SKILL.md"는 `skill_runs`나 `prior`의 도구 호출에서 추정된 스킬의 SKILL.md. "가까운 AGENTS.md/CLAUDE.md"는 그 SKILL.md 디렉터리에서 상위로 올라가며 처음 만나는 AGENTS.md/CLAUDE.md (없으면 repo root). 추정 불가하면 repo root CLAUDE.md를 기본값으로.

5. 출력 스키마 — JSON 한 덩어리만, 다른 텍스트 없이. `event_index`는 인덱스 JSON의 `events[N]` 배열 위치 정수:

   ```json
   {
     "classifications": [
       {"event_index": 3, "label": "correction", "reason": "직전 grep을 정정"},
       {"event_index": 7, "label": "noise", "reason": "메타 잡담"}
     ],
     "proposals": [
       {
         "id": "P1",
         "event_indexes": [3],
         "target_file": "<absolute path>",
         "is_external_cache": false,
         "change_kind": "edit",
         "patch": "<unified diff applicable with `git apply`>",
         "rationale": "1~2문장"
       }
     ],
     "skipped": [{"event_index": 5, "reason": "신뢰도 낮음"}]
   }
   ```

6. 지시: "events array를 우선 읽고 같은 turn 근처의 인접 event들이 인과 사슬임에 주목. 필요할 때만 `Bash`로 jsonl의 해당 turn 범위만 발췌. 메인 transcript는 절대 통째 읽지 말 것. 결과 JSON만 반환."

## Phase 2 — 적용 루프

서브에이전트 반환 JSON 파싱 후:

> Phase 1 결과나 회고를 별도 보고서 파일로 저장하지 않는다. JSON을 콘솔에 직접 풀어 한 건씩 사용자 승인 받고 끝. 부산물 파일은 `upstream-suggestions.md` 하나만 (해당 케이스 있을 때만).

1. `is_external_cache: true` 인 proposal은 분리해 `docs/superpowers/evolutions/YYYY-MM-DD-upstream-suggestions.md`에 append (없으면 생성). Edit 시도 안 함.
2. 나머지 proposal을 1번부터 차례로 사용자에게 제시:

   ```
   P1. <target_file>
     근거: <signal_ids> (snippet)
     이유: <rationale>

     [patch diff]

     적용? [y / n / skip / edit]
   ```

3. 사용자 응답에 따라:
   - **y**: `git apply <patch-file>` → `git commit -m "evolve: <subject>"` (한 patch = 한 commit, `git revert <sha>` 한 줄로 롤백). target이 `~/.claude/plugins/cache/` 경로면 적용 거부하고 upstream-suggestions로 분리.
   - **edit**: 사용자에게 patch 편집 기회 제공 후 y와 동일하게 처리.
   - **skip / n**: 다음 proposal로.

4. `--dry-run` 인자가 있으면 Phase 2 전체 스킵, proposal 목록만 출력.

5. 마무리: 적용된 commit sha 목록과 upstream 파일 경로 출력.

## Safety

- 시작 시 `git status --porcelain`이 비어 있어야 함 (dirty면 거부)
- 외부 캐시(`~/.claude/plugins/cache/`) 경로는 적용 거부 → upstream-suggestions로 분리
- patch는 적용 전 반드시 사용자에게 diff로 보여주기
- 각 변경은 별도 commit → `git revert <sha>` 한 줄로 개별 롤백 가능
