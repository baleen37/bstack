# evolve 단순화 — body-hash 매칭 폐기

## 배경

`/me:evolve`는 transcript 신호를 스킬 본문에 매핑하기 위해 **호출 시점 주입 본문을 해싱**하고, 디스크의 현재
SKILL.md 본문 해시와 비교해 `stale` / `dropped` / `advisory(stale_events)` 로 분기한다. 이 매칭 모델이
인덱서(1059줄)·SKILL.md(240줄)·테스트(1253줄) 복잡도의 대부분을 차지한다. 22개 커밋 중 거의 전부가 이
매칭의 엣지케이스(`${CLAUDE_PLUGIN_ROOT}` 복원, ARGUMENTS 꼬리 제거, frontmatter 제거, false-stale)다.

## 실제 evolve를 돌려 얻은 증거

`/me:evolve --skill evolve` 실행 결과:

- evolve는 10개 세션에서 **5개의 서로 다른 본문 해시**(v17.18.1 → v17.23.4)로 등장하고, 현재 repo 본문
  (`5a12579e`)은 그 중 **무엇과도 매칭되지 않는다**.
- 배포된 캐시 인덱서(17.23.4, advisory 없음)는 그래서 evolve를 **통째로 drop** → `events: []`, 제안 근거
  0. 정작 3 interrupt + 3 error + 6 repeat 신호는 이전 본문들에 그대로 있다.
- repo 인덱서(advisory 있음)는 19 stale_events를 노출하지만, 그 신호 대부분은 evolve **자기 개발 노이즈**
  (반복 `bun build-index.ts`, evolve 자기 파일 반복 Read)다.

대조군 — 다른 스킬은 깨끗이 매칭된다:

- `--skill handoff`: 3 bodies, 28 events, **stale 아님**
- `--skill research`: 2 bodies, 30 events, **stale 아님**
- `--skill pickup`: 2 bodies, 4 events, **stale 아님**

결론: body-hash 매칭은 **안정 배포된 스킬에서는 잘 동작하지만**, 자기 자신을 고치면서 바로 재실행하는 evolve
같은 fast-churn 스킬에서만 병적으로 실패한다. 매칭 모델은 가장 빠르게 진화하는 스킬에서 가장 잘 깨지는데, 그게
바로 evolve의 주 사용처다.

## 결정

**body-hash 매칭을 폐기한다.** 인덱서는 스킬 이름별로 신호를 버전 무관하게 합산만 하고, 현재 본문과의 대조는
하지 않는다. "이 신호가 이미 고쳐졌는지" 확인은 SKILL.md를 직접 읽는 Phase 1 subagent의 책임으로 옮긴다.

선택된 안: **신호 통합 + 현재 본문 인식 완전 제거** (인덱서는 디스크 SKILL.md를 읽지 않는다).

## 설계

### 인덱서 데이터 모델

제거:

- 해싱/정규화: `bodyHash`, `restorePluginRoot`, `stripBaseDirLine`, `stripFrontmatter`, `currentBodyHash`,
  `skillVersion`(버전 추출은 baseDir 경로에서 그대로 유지하되 해시 비교에는 안 씀), `BASE_DIR_LINE`,
  `ARGUMENTS_TAIL`, `shortHash`
- 분기 상태: `ObservedBody` / `observed_bodies[]`, `stale`, `dropped`, `drop_reason`, `stale_events[]`,
  `DropReason`, `dropReasonFor`, `strongestObservedBody`
- 디스크 SKILL.md 조회: `repoSkillPath`, `currentBodyHash`, `findRepoRoot`(인덱서가 더는 repo 본문을 안 읽음)
- `SkillAccumulator`의 per-hash 맵 (`versionsByHash`/`seenByHash`/`eventsByHash`) → 평면화

`RecentSkill` 새 형태:

```jsonc
{
  "name": "evolve",
  "skill_path": "<호출 시점 cache SKILL.md 경로>",
  "versions": ["17.18.1", "...", "17.23.4"],  // 등장한 모든 버전 (컨텍스트용)
  "seen_in": ["<session_id>", ...],
  "signal": "3 interrupt, 3 error, 6 repeat, 10 user, 2 agent",
  "events": [ /* 모든 본문 신호 합산, 각 event에 session 태그 */ ]
}
```

정렬: 신호 weight(interrupt+error+repeat) → event 수 → 이름. stale/drop 보조키 없음.

`skill_path`는 호출 시점 cache 경로(편집 대상 매핑은 SKILL.md 지시문이 `plugins/*/skills/<name>/`로 안내).
repo 본문 경로 해석은 Phase 1/2의 책임으로 남긴다 — 인덱서는 transcript만 본다.

### 인덱서: 유지

- 단일 세션 경로(`SessionIndex` = `summary` + `events[]`) 그대로.
- `buildEvents` 추출(user/skill/interrupt/error/agent/repeat, `prior`, pseudo-user 필터, repeat 감지,
  Skill-도구 주입 앵커) 그대로 — 검증된 핵심 가치.
- `FMT.*` + `warnIfFormatLooksBroken` 포맷 드리프트 방어 그대로.
- 활성 스킬 기준 이벤트 귀속(turn-proximity, cross-session `session` 태그) 그대로.
- `loadTurns`의 주입 파싱은 유지하되 본문 해싱은 안 함 — `name`/`version`/`turn`만 기록.

### SKILL.md

240 → ~120줄. Phase 0의 stale/dropped/advisory/observed_bodies/stale_events 분기와 Index Notes의
관련 단락, revalidation probe 렌즈 제거. Phase 0 정지 조건:

- 단일 세션 `events[]` 비어있음 → `no improvement signals found in this session`
- recent `skills[]` 비어있음 → `no invoked skills found in recent sessions`
- 신호 0인 스킬만 → `no improvement signals found`

Phase 1/2(probe → propose → approve)와 argument mapping rules는 유지(실제 `parseArgs` 함정).

### 테스트

stale/dropped/advisory/observed_bodies/hash-matching 테스트 케이스 삭제. 추출·귀속·arg-parsing·repeat·
pseudo-user·포맷드리프트 테스트 유지. 새 평면 `RecentSkill` 형태에 대한 어서션으로 갱신.

## 검증

- `bats tests/me/evolve-build-index.bats tests/me/evolve-skill.bats` 통과.
- `bun plugins/me/skills/evolve/scripts/build-index.ts --skill evolve` 가 이제 `dropped` 대신
  `evolve | 3 interrupt 3 error 6 repeat …`(전 신호 노출)로 나온다.
- `--skill handoff` / `--skill research` 가 동일 신호를 평면 형태로 계속 노출(회귀 없음).
