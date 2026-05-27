# /me:evolve — Transcript 기반 Skill·Doc 진화 도구

## 배경

Claude Code 세션을 한참 돌리고 나면 같은 실수·우회·교정이 반복된다. Geoffrey Huntley의 Ralph Loop 글에서 지적하듯, 이런 실패 신호는 다음 반복 때 프롬프트·규칙 파일에 "인코딩"되어야 더 이상 반복되지 않는다. Huntley는 이걸 사람이 직접 `PROMPT_build.md` / `AGENTS.md`를 손으로 고치며 처리하지만, 그 작업은:

- 어떤 신호가 있었는지 찾기 위해 transcript를 직접 뒤지는 비용이 큼
- 어떤 파일을 고쳐야 할지 매번 판단해야 함
- 시간이 지나면 잊혀짐

`/me:evolve`는 이 수동 진화 단계를 **반자동화**한다. 자동으로 신호를 추출하고 어디를 어떻게 고치자고 제안하되, 적용은 사람이 한 건씩 승인한다.

## 합의된 원칙

- 진화 단계의 자동화 수준은 **L2(제안 + 승인 후 적용)**. 자동 commit/push 안 함, 한 건씩 명시 승인.
- 분석 입력은 **세션 transcript 파일** (`~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`). 외부 메모리·로그 안 봄.
- 수정 대상은 **로컬 git 추적 파일만**. 외부 플러그인 캐시는 수정 차단, 별도 upstream 제안 파일에만 남김.
- **회고 보고서는 안 만든다**. 신호와 제안을 콘솔에 즉시 출력하고 한 건씩 처리. 부산물 최소화.
- 트레이서빌리티는 **commit 메시지**에서만 보장 (신호 인용 + 적용된 변경).
- **메인 에이전트가 raw transcript를 직접 안 읽는다**. transcript는 자기 자신의 대화 기록 — 통째 로드하면 컨텍스트 폭발. 사전 인덱스 + 서브에이전트로 우회.

## 접근법

**A안 (선택됨): TS 인덱스 빌더 → 서브에이전트 부분 분석 → 메인이 적용**

세 단계로 분리:

1. **Phase 0 (인덱스 빌더)**: TS 스크립트가 jsonl을 파싱해 세션 트리(JSON)를 생성. 토큰 거의 0.
2. **Phase 1 (서브에이전트 분석)**: 서브에이전트가 트리를 받아 의심 구간 식별, 필요한 turn 범위만 다시 발췌해 깊이 읽음, 신호별로 후보 파일 + patch 제안 반환.
3. **Phase 2 (메인이 적용)**: 메인 에이전트가 결과를 받아 사용자에게 한 건씩 승인 받고 Edit + 개별 commit.

검토 후 채택하지 않은 안:
- B (메인이 통째 분석): transcript = 메인 자신의 대화 기록. 통째 로드 시 컨텍스트 폭발.
- C (Huntley 스타일 자동 commit + git reset 롤백): 변경 단위가 크면 부분 롤백 어려움. 개별 commit이 안전.
- D (회고 보고서 산출 후 일괄 적용): 잡파일 누적, 두 번 일하는 느낌. 콘솔 즉시 처리가 가볍다.

## 사용법

```
/me:evolve                          현재 세션 회고
/me:evolve me:research              해당 스킬에 집중해 최근 세션 분석
/me:evolve --session <id>           특정 세션 ID 회고
/me:evolve --since 7d me:browse     7일치 + 스킬 필터
/me:evolve --dry-run                제안만 보고 적용 안 함
```

기본값(인자 없음)은 현재 세션. 인자에 스킬명이 있으면 해당 스킬이 등장한 세션·구간으로 좁힌다.

## 입력

- 위치: `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`
  - encoded-cwd = 현재 cwd의 `/`를 `-`로 치환한 디렉토리명
- 한 줄 한 JSON. `type` 필드로 구분: `user` / `assistant` / `system` / `attachment` / `mode` 등
- 분석 대상은 `user` / `assistant`만. 나머지는 무시
  - 그중에서도 `type=="user"` & content가 `string` 또는 `[{type:"text"}]` 인 것만 **실제 사용자 발화**
  - `[{type:"tool_result"}]`는 도구 출력이므로 분석에 안 씀

## Phase 0 — 인덱스 빌더

**파일**: `plugins/me/skills/evolve/scripts/build-index.ts`
**실행**: `bun plugins/me/skills/evolve/scripts/build-index.ts <session-jsonl-path> [--skill <name>]`
**출력**: stdout에 JSON (아래 스키마)

### 책임 분리: 결정적 vs 의미

Phase 0(인덱서)는 **결정적 메타데이터**만 추출한다. "이게 사용자 교정인가" 같은 *의미 판정*은 절대 안 함 — 그건 Phase 1(LLM)의 일이다. 룰 베이스 분류는 본질적 한계(우연한 단어 등장으로 false positive, 새로운 표현 형태로 false negative)가 있어 사용 안 함.

- **인덱서가 하는 것**: turn 카운트, 같은 명령 N회 반복, interrupt 마커 검출, 슬래시 커맨드 위치, user 발화 메시지 수집 (분류 없이 raw)
- **인덱서가 하지 않는 것**: 정정 vs 질문 vs 긍정 vs 잡담의 분류, "이게 진짜 문제 신호인가" 판단

### 스키마 (TS 타입)

설계 원칙: **flat events 배열이 메인 데이터**. 시간 순서가 array 인덱스로 표현되어 "X after Y" 추론이 무료. cross-cutting view (`skill_runs`)는 같은 스킬을 N회 호출한 패턴만 한눈에 보이게 하기 위한 작은 보조.

```typescript
type EventKind =
  | "user"          // 사용자 발화 (LLM이 분류할 raw 입력)
  | "skill"         // 슬래시 커맨드 호출 (/me:foo, <command-name>/me:foo</command-name>)
  | "interrupt"     // interrupt 마커 (메타데이터)
  | "error"         // tool_result.is_error == true
  | "agent"         // Agent tool 호출 (서브에이전트 분기)
  | "large_out"     // tool_result content > 10KB
  | "repeat";       // 같은 Bash prefix / Read path 3회 이상

interface Event {
  t: number;                  // turn 번호 (1-based, user+assistant만 카운트)
  kind: EventKind;
  // kind별 최소 필드:
  text?: string;              // user/error: 본문 앞 200자
  prior?: string[];           // user: 직전 assistant 행동 요약 1~3개 ("Bash: grep -r foo")
  name?: string;              // skill: 스킬 이름 ("me:browse")
  by?: "user" | "assistant";  // interrupt: 누가 끊었는지
  tool?: string;              // error/large_out: 어떤 도구
  desc?: string;              // agent: input.description
  sub?: string;               // agent: input.subagent_type
  model?: string;             // agent: input.model
  bytes?: number;             // large_out: tool_result content 크기
  pattern?: string;           // repeat: 반복된 prefix 또는 path
  n?: number;                 // repeat: 반복 횟수
}

interface SkillRun {
  name: string;               // "me:verify"
  turns: number[];            // [383, 387, 389, 391]
}

interface SessionIndex {
  session_id: string;
  session_title?: string;     // ai-title 라인의 aiTitle (Phase 1 컨텍스트 헤더)
  turns: number;              // user+assistant turn 총 개수
  tools_top: Array<[string, number]>;  // [["Bash", 32], ...] top 10
  skill_runs: SkillRun[];     // 같은 스킬 호출 모음 (cross-cutting)
  signal_counts: Record<EventKind, number>;  // 카운트만, 분류 없음
  events: Event[];            // 메인 데이터: 시계열 모든 이벤트
}
```

**제거된 것** (이전 스키마와의 차이):
- `groups`, `turn_range`, `topic_hint`, `tools_used` per-group → flat `events`로 흡수
- `context_pointer` → dead weight. LLM은 jsonl 직접 안 봄
- `signals[].id` (S1, S2...) → events array index로 대체. 필요하면 `events[N]`으로 참조
- `interrupts_total`, `user_messages` → `signal_counts`로 통일
- `skill_invocations` (turn당 1개 객체) → `skill_runs` (스킬당 turn 배열)로 통합

### Event 추출 규칙

모든 event는 시간 순서대로 `events[]`에 emit. **kind별 최소 필드만 채움.** 분류·의미 판정 없음.

**`user`** — 모든 user 발화 (`type=="user"` & content가 `string` 또는 `[{type:"text"}]`)
- `text` = 본문 앞 200자
- `prior` = 직전 assistant turn 1~3개의 tool_use 요약 (`"Bash: grep -r foo"`, `"Read: SKILL.md"`)

**`skill`** — 슬래시 커맨드 호출. user 발화 중 `/<name>` prefix 또는 `<command-name>/<name></command-name>` 태그 검출
- `name` = 스킬 이름 (`/` 제외)

**`interrupt`** — interrupt 마커
- user turn에 `interruptedMessageId` → `by: "user"`
- assistant turn의 `stop_reason == "interrupted"` → `by: "assistant"`
- 한 사건당 1 event, 인접 turn 중복 제거

**`error`** — `tool_result.is_error == true`
- `text` = 에러 메시지 앞 200자
- `tool` = 직전 assistant tool_use의 name

**`agent`** — assistant tool_use 중 `name == "Agent"`
- `desc` = `input.description`
- `sub` = `input.subagent_type` (있으면)
- `model` = `input.model` (있으면)

**`large_out`** — `tool_result` content > 10KB
- `tool` = 직전 assistant tool_use의 name
- `bytes` = content 길이

**`repeat`** — 같은 Bash command 첫 2 토큰 prefix 또는 같은 Read file_path 3회 이상
- 1 event per pattern (각 반복 turn마다 emit하지 않음 — 마지막 등장 turn에 한 번)
- `pattern` = 반복된 prefix 또는 path
- `n` = 반복 횟수

### `session_title` 추출
- jsonl 라인 중 `type == "ai-title"` 인 것의 `aiTitle` (최신값)
- 없으면 필드 생략

### `skill_runs` 집계
- `events` 스캔 후 `kind == "skill"`만 모아 `name`별로 묶음
- 각 SkillRun은 `{name, turns: [t1, t2, ...]}` (호출 turn 배열)

### Skill 필터 (`--skill` 인자 있을 때)
- `skill_runs`를 해당 이름만 남김
- `events`는 해당 스킬의 첫 호출 turn 이후로 trim (또는 호출 사이 구간만 유지)

## Phase 1 — 서브에이전트 분석

메인 에이전트는 다음을 한다:
1. Phase 0 스크립트 실행해 인덱스 JSON 획득
2. 서브에이전트(general-purpose) 1개 디스패치, 다음을 전달:
   - 인덱스 JSON
   - 후보 파일 매핑 표 (아래)
   - 출력 스키마 (아래)
3. 서브에이전트는 인덱스 트리를 우선 읽고, 필요한 경우 `Bash`로 jsonl의 해당 turn 범위만 발췌해 깊이 분석

### 분류와 매핑 (서브에이전트가 책임)

서브에이전트는 두 가지를 한다:

**1) `user_message` signal 분류** — 각 user_message signal을 다음 중 하나로 분류 (또는 무시):

- **correction** — 직전 assistant 행동의 방향을 정정하는 의도 ("그게 아니라 X", "stop, do Y instead")
- **success** — 직전 assistant 행동에 대한 긍정 피드백 ("좋아", "perfect", "그렇지")
- **directive** — 새 작업 지시 (정정/긍정 아님)
- **question** — 질의
- **noise** — 분석 가치 없는 메타·잡담

분류 기준은 *직전 assistant 행동(prior_actions)과의 관계*. 단어가 아니라 문맥이 결정함.

**2) 분류 결과 + interrupt/verbose 신호 → 후보 파일 매핑**:

| 신호 패턴 | 1순위 후보 | 2순위 |
|---|---|---|
| correction 다수 → 해당 스킬 미발견 / "안 쓰네" | 해당 SKILL.md (description, 트리거 키워드) | 가까운 AGENTS.md |
| correction → 스킬 invoke 후에도 규칙 위반 | 해당 SKILL.md (본문, Red Flags 섹션) | — |
| verbose_exploration + 결국 X를 찾음 | 가까운 AGENTS.md (Key Files / Subdirectories) | CLAUDE.md |
| correction → 프로젝트 룰/관례 위반 | 가까운 CLAUDE.md | AGENTS.md |
| success → 한 스킬이 잘 작동 | 자주 호출된 SKILL.md (강화) | — |
| interrupt + 직전 행동이 명백히 잘못됨 | 해당 SKILL.md | AGENTS.md |

### 서브에이전트 출력 스키마

```typescript
interface Proposal {
  id: string;                // "P1", "P2", ...
  signal_ids: string[];      // 근거 신호
  target_file: string;       // 절대 경로
  is_external_cache: boolean;
  change_kind: "edit" | "add-section";
  patch: string;             // unified diff 형식, 그대로 적용 가능
  rationale: string;         // 1~2문장
}

interface AnalysisResult {
  proposals: Proposal[];
  skipped_signals: Array<{id: string; reason: string}>;
}
```

## Phase 2 — 메인 적용 루프

서브에이전트 결과를 받고:

1. `is_external_cache: true` 인 proposal은 별도 분리 → `docs/superpowers/evolutions/YYYY-MM-DD-upstream-suggestions.md`에 누적 추가만, Edit 시도 안 함
2. 나머지를 한 건씩:
   - 콘솔 출력:
     ```
     P1. plugins/me/skills/browse/SKILL.md
       근거: S1 (사용자 교정 "그게 아니라 X")
       이유: <rationale>

       [patch diff]

       적용? [y/n/skip/edit]
     ```
   - y: Edit 적용 → `git add` → 개별 commit (메시지 형식 아래)
   - edit: 사용자가 patch 즉석 수정 후 적용
   - skip / n: 다음으로
3. 마무리: 적용된 commit sha 목록 + upstream 파일 경로 출력

### Commit 메시지 형식

```
evolve(<scope>): <한 줄 요약>

Signal: <신호 snippet 1줄>
Session: <session-id>
```

## 안전 가드

- **외부 캐시 차단**: 경로가 `~/.claude/plugins/cache/`로 시작하면 Edit 시도 자체를 차단 (Phase 2에서)
- **dirty tree 차단**: 시작 시점 `git status --short` 결과가 비어 있어야 함
- **dry-run**: `--dry-run` 인자로 Phase 2의 Edit/commit 스킵, proposal 출력만
- **개별 commit**: 변경 한 건당 commit → `git revert <sha>` 한 줄로 개별 롤백
- **patch 미리보기 강제**: 사용자가 y를 누르기 전에 diff가 반드시 표시됨

## 비범위

- transcript 자체 수집·저장 (Claude Code가 이미 함)
- 새 스킬 생성 (`writing-skills` 영역)
- 자동 트리거 (SessionEnd hook 등 — 명시적 수동만)
- 여러 세션 자동 병합 분석 (1순위는 단일 세션, 다중 세션은 인자로 좁힌 경우만)
- 수정 결과를 다른 사람과 공유 (그건 PR 단계에서 따로)
