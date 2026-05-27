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

### 트리 스키마 (TS 타입)

```typescript
type SignalKind =
  | "user_correction"        // 사용자 교정/중단
  | "verbose_exploration"    // 장황한 탐색
  | "success_pattern"        // 성공 패턴
  | "interrupt";             // assistant 응답이 interrupt로 끊김

interface Signal {
  id: string;                // "S1", "S2", ...
  kind: SignalKind;
  turn_range: [number, number];  // 단일 turn이면 [n,n]
  snippet: string;           // 핵심 문장 1줄 (잘라서 80자 이하)
  detail?: string;           // "같은 grep 4회 반복" 같은 부가 설명
  context_pointer: {         // 서브에이전트가 더 읽고 싶을 때 발췌용
    jsonl_path: string;
    turn_range: [number, number];
  };
}

interface TurnGroup {
  turn_range: [number, number];
  topic_hint: string;        // "me:browse 호출 구간" 등 자동 추정
  tools_used: Record<string, number>;  // {Bash: 12, Read: 2}
  signals: Signal[];
}

interface SkillInvocation {
  name: string;              // "me:browse"
  turn: number;
  outcome: "completed" | "interrupted_at_<n>" | "abandoned";
}

interface SessionIndex {
  session_id: string;
  jsonl_path: string;
  turns_total: number;
  user_messages: number;
  interrupts_total: number;
  tools_top: Array<[string, number]>;  // [["Bash", 66], ...] top 10
  skill_invocations: SkillInvocation[];
  groups: TurnGroup[];
  // 노이즈 줄이려고: 신호 없는 group은 생략
}
```

### 신호 추출 규칙 (스크립트가 적용)

**A. user_correction**
- 사용자 발화 (string 또는 text content) 중:
  - 한국어: `^(아니|그게 아니|그러지 말|다시|잠깐|stop|wait)`
  - 영어: `\b(no|stop|wait|hold on|don't|that's not)\b`
- `@<path>` 형태로 경로 재지정하는 메시지
- 매칭 시 turn 위치 + snippet 80자 캡처

**B. interrupt**
- assistant 메시지에서 `stop_reason == "interrupted"` 또는 `interruptedMessageId` 필드 존재
- 직전 사용자 발화와 묶어 1건의 signal

**C. verbose_exploration**
- 연속된 5개 이상의 tool_use에서:
  - 같은 file_path를 Read 3회 이상 → 1 signal
  - 같은 command prefix(Bash) 3회 이상 → 1 signal
  - 동일 grep/find 인자 변종 3회 이상 → 1 signal

**D. success_pattern**
- 사용자 발화 중 `^(좋아|perfect|그렇지|yes|ok|good)` 직전 5턴 동안 호출된 스킬 1건을 signal로 기록

### Group 분할 규칙
- 슬래시 커맨드(`/<skill-name>`) 호출 지점에서 새 group 시작
- 그 외에는 50턴 슬라이딩 윈도우로 자르되 signal 클러스터를 깨지 않도록 인접 윈도우 병합

### Skill 필터 (`--skill` 인자 있을 때)
- `skill_invocations`를 해당 이름만 남김
- 해당 invocation이 포함된 group만 출력 (다른 group 생략)

## Phase 1 — 서브에이전트 분석

메인 에이전트는 다음을 한다:
1. Phase 0 스크립트 실행해 인덱스 JSON 획득
2. 서브에이전트(general-purpose) 1개 디스패치, 다음을 전달:
   - 인덱스 JSON
   - 후보 파일 매핑 표 (아래)
   - 출력 스키마 (아래)
3. 서브에이전트는 인덱스 트리를 우선 읽고, 필요한 경우 `Bash`로 jsonl의 해당 turn 범위만 발췌해 깊이 분석

### 후보 파일 매핑 표 (서브에이전트에게 전달)

| 신호 패턴 | 1순위 후보 | 2순위 |
|---|---|---|
| 스킬 미발견 / "이 스킬 안 쓰네" | 해당 SKILL.md (description, 트리거 키워드) | 가까운 AGENTS.md |
| 스킬 invoke 후에도 규칙 위반 | 해당 SKILL.md (본문, Red Flags 섹션) | — |
| 장황한 탐색 + 결국 X를 찾음 | 가까운 AGENTS.md (Key Files / Subdirectories) | CLAUDE.md |
| 프로젝트 룰/관례 위반 | 가까운 CLAUDE.md | AGENTS.md |
| 성공 패턴 | 자주 호출된 SKILL.md | — |

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
