# evolve `--recent` — 멀티세션 전반 검토 설계

## 배경 / 문제

현재 `/me:evolve`는 **한 세션**의 transcript를 분석해 그 세션에서 실행된 **특정 skill**(또는 nearest AGENTS/CLAUDE.md)을 개선한다. 사용자는 "특정 skill 하나가 아니라, 최근 작업 전반을 보고 문제 있는 skill들을 한 번에 검토"하고 싶을 때가 있다.

그런데 전반 검토를 하면 **"이미 고쳐진 skill을 옛 신호로 또 건드리는 헛수고"** 가 발생한다. 핵심 요구:

- 최근 여러 세션을 모아 분석한다.
- 단, **세션 호출 시점 이후 내용이 이미 바뀐 skill**은 그 신호를 제외한다 (= 이미 진화함).
- "이미 바뀜" 판단은 **버전 번호가 아니라 SKILL.md 본문 내용의 해시 변화**로 한다. (버전만 오르고 내용은 그대로인 경우가 있으므로 버전은 신뢰할 수 없는 신호.)

## 핵심 발견 (subagent 검증 완료)

transcript jsonl은 skill 호출 시점의 **SKILL.md 본문 전체**를 그대로 보존한다:

- 위치: `type:"user"`, `message.role:"user"`, `isMeta:true` 인 메시지.
- 연결: 그 메시지의 `sourceToolUseID` 가 Skill `tool_use` 의 id와 일치.
- 내용: `message.content[0].type:"text"` 의 텍스트. 첫 줄은 `Base directory for this skill: <abs path>`, 빈 줄, 그 뒤로 **frontmatter가 제거된** 마크다운 본문 전체. (Skill 의 `tool_result` 블록은 `"Launching skill: <name>"` 문자열만 가지므로 본문 출처로 쓰지 않는다.)
- repo skill과 외부 캐시 skill 모두 **동일한 형태**로 남는다. (repo `me:*` skill도 Base directory는 플러그인 캐시 경로로 해석되지만, 본문 자체는 동일하게 존재.)

→ 따라서 **git도 버전 번호도 필요 없다.** transcript에 박힌 "그때 본 본문"의 해시와 현재 디스크 본문의 해시를 직접 비교하면 결정론적으로 "변경 여부"를 알 수 있고, repo/캐시 skill에 동일하게 작동한다.

## "이미 진화함(stale)" 판정 규칙

```
hash_then = sha(세션 jsonl에서 sourceToolUseID로 연결된 isMeta 본문 − "Base directory" 첫 줄)
hash_now  = sha(현재 디스크 SKILL.md 본문 − YAML frontmatter)

hash_then == hash_now  → 세션 이후 안 바뀜 → 신호 유효 (개선 대상)
hash_then != hash_now  → 이미 진화함     → 그 skill의 그 신호는 stale (제외)
```

정규화 규칙(양쪽 동일 적용): `hash_then`은 본문에서 첫 줄(`Base directory for this skill: …`)과 뒤따르는 빈 줄을 제거한 나머지. `hash_now`는 디스크 SKILL.md에서 YAML frontmatter(`---` … `---`)를 제거한 나머지. 양쪽 모두 끝 공백 제거(rstrip) 후 해시. (subagent가 byte-level로 두 본문이 일치함을 검증함.)

현재 디스크 SKILL.md를 찾을 수 없는 경우(예: 더 이상 설치돼 있지 않은 skill): 비교 불가 → 그 skill은 통째로 제외(현역 아님으로 간주)하고 `events`에 포함하지 않는다.

## 동작 / CLI

기존 단일세션 동작은 **그대로 유지**한다. 새 플래그를 추가한다:

```
/me:evolve                     현재 세션 1개 분석 (기존)
/me:evolve --session <id>      특정 세션 1개 분석 (기존)
/me:evolve --recent            최근 10개 세션 전반 검토 (신규, 기본 N=10)
/me:evolve --recent <N>        최근 N개 세션 전반 검토 (신규)
/me:evolve --dry-run           제안만 (기존, --recent와 조합 가능)
```

`--recent` 와 `--session` 동시 지정은 모순 → 에러로 거부.

## 구현 — build-index.ts 확장 (별도 스크립트 신설 안 함)

기존 `loadTurns` / `buildEvents` / `buildSummary` 를 재사용하고, 멀티세션 루프 + 해시 비교만 얹는다.

### 1. 인자 파싱
- `--recent [N]` 추가. N 생략 시 기본 10. `parseArgs`가 `{ recent?: number }` 를 반환.
- `--recent`와 `--session`/positional jsonlPath 동시 지정 시 exit 2 (모순).

### 2. 세션 목록 선정
- `resolveTranscriptPath`의 디렉터리 탐색 로직을 재사용해, 프로젝트 디렉터리에서 `.jsonl`을 mtime 내림차순 정렬 후 **상위 N개**를 고른다. (현재는 `[0]`만 쓰는 것을 N개로.)

### 3. skill 호출 시점 본문 해시 추출
- `loadTurns`가 현재 버리는 정보를 살려야 한다. jsonl 라인 중 `isMeta:true` + `message.content[0].type:"text"` + 첫 줄이 `Base directory for this skill:` 인 메시지를, 같은 turn 근방의 Skill 호출(`sourceToolUseID` ↔ Skill tool_use id)과 연결.
  - 구현상 가장 단순한 방법: jsonl을 한 번 더(또는 loadTurns 내에서) 스캔하며 `toolUseID → skill name → injected body` 매핑을 만든다. skill name은 Skill tool_use의 `input.skill`(또는 주입 본문이 가리키는 Base directory의 디렉터리명)로 식별.
- 각 호출에 대해 `hash_then` 계산.

### 4. 현재 디스크 해시 + stale 판정
- skill name → 현재 SKILL.md 경로 해석:
  - repo skill: Base directory 경로에서 디렉터리명을 얻어 `plugins/*/skills/<name>/SKILL.md` 를 찾는다(또는 Base directory가 가리키는 경로의 SKILL.md를 직접 읽되, 캐시 경로면 그 캐시의 현재 SKILL.md).
  - 단순화: **주입 본문의 Base directory 경로 + `/SKILL.md`** 를 현재 본문 출처로 삼는다. 그 파일이 존재하면 frontmatter 제거 후 `hash_now`. (캐시/ repo 동일하게 처리됨.)
- `hash_then != hash_now` → 그 skill의 events에 `stale: true` 표시. 파일 없음 → 그 skill 제외.

### 5. 통합 출력 (멀티세션 JSON)
- `--recent` 일 때 출력 스키마를 확장한다. 단일세션 모드 출력은 기존 그대로 유지(하위 호환).

```jsonc
{
  "mode": "recent",
  "session_count": 10,
  "sessions": [{ "session_id": "...", "session_title": "...", "turns": 42 }],
  "skills": [
    {
      "name": "me:qa",
      "skill_path": "/abs/.../skills/qa/SKILL.md",   // 현재 디스크 경로 (제안 target 후보)
      "stale": false,                                  // 세션 이후 본문 변경 여부
      "seen_in": ["sessA", "sessB"],                   // 등장한 세션
      "events": [ /* 기존 Event[] 형식. 단 t는 (session_id, turn) 로 식별 */ ]
    }
  ],
  "summary": { "headline": "10 sessions · 6 skills · 3 stale", "clusters": [/* 선택 */] }
}
```

- `events[]`의 `t`는 멀티세션에서 충돌하므로 각 event에 `session` 식별자를 추가(또는 `"sessA#37"` 형태). subagent가 evidence를 인용할 때 세션을 알 수 있어야 함.
- **stale: true 인 skill의 events는 출력에서 제외**하거나, 포함하되 명확히 `stale:true`로 표기해 Phase 1 subagent가 절대 제안하지 않도록 한다. → **제외하는 쪽으로 결정**(헛수고 방지가 목적이므로, stale skill은 아예 events에서 빼고 `skills[]` 메타에만 `stale:true, dropped:true`로 남겨 "왜 빠졌는지" 가시화).

### 변경하지 않는 것
- **규칙 기반 분류(regex/keyword)를 build-index.ts에 추가 금지** — 기존 금지 사항 유지. 분류는 Phase 1 subagent(LLM)가 한다.
- TypeScript(Bun) 유지. shell/Python 대안 금지.

## Phase 1 (subagent) 변경

- 프롬프트에 멀티세션 인덱스 JSON을 넘긴다. subagent는 `skills[]`를 순회하며 skill별로 신호를 분석.
- target-file 선택은 기존 규칙 유지하되, 멀티세션에서는 `skill_path`가 인덱스에 이미 들어있으므로 "nearest" 해석이 더 쉬움.
- stale skill은 인덱스에서 이미 제외됐으므로 subagent가 신경 쓸 필요 없음. (안전망: 인덱스에 `stale:true`가 남아 들어오면 제안 금지하라고 명시.)
- 출력 스키마(classifications/proposals)는 기존과 동일. proposal의 `event_indexes`는 멀티세션 식별자(`sessA#37`)를 참조할 수 있어야 함.

## Phase 2 (apply loop) 변경

- 변경 없음. 제안 단위(proposal)는 동일하게 `target_file` + `patch` 형식이고, 한 제안 = 한 커밋, 외부 캐시는 upstream-suggestions 우회.
- 단 evidence 표기에 세션 식별자가 포함됨.

## 안전장치 (기존 유지)

- 시작 시 `git status --porcelain` 비어있어야 함(더티 트리 거부).
- 외부 캐시 경로(`~/.claude/plugins/cache/`)는 편집 거부 → upstream-suggestions 우회.
- 패치 적용 전 항상 diff 표시, 변경마다 개별 커밋.
- `--dry-run`은 main agent만 소비, build-index.ts에 전달 금지.

## 테스트 관점

- build-index.ts `--recent N` 단위 동작: 세션 N개 선정, skill 집계, stale 판정 분기(hash 같음/다름/파일없음). BATS보다는 스크립트 자체에 작은 fixture jsonl로 검증하는 게 적합.
- "버전 올랐지만 내용 동일" 케이스가 stale=false로 나오는지(= 내용 해시 기준 동작) 명시적으로 검증.
- 기존 단일세션 출력이 바뀌지 않았는지(하위 호환) 회귀 확인.
- CLAUDE.md 메모리(`feedback_avoid_over_testing_skills`): 문서/지시문 변경은 과한 테스트 금지. 여기서는 build-index.ts 로직 변경이 핵심이라 그 부분만 최소 검증.
