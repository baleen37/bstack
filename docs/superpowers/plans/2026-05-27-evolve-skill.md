# /me:evolve Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** transcript 기반으로 SKILL.md/AGENTS.md/CLAUDE.md를 반자동 진화시키는 `/me:evolve` 스킬을 만든다. TS 인덱스 빌더 + 서브에이전트 분석 + 메인 적용(개별 commit)의 3-Phase 파이프라인.

**Architecture:** 단일 스킬 `plugins/me/skills/evolve/` — `SKILL.md`(흐름 정의) + `scripts/build-index.ts`(Phase 0 인덱서) + `scripts/apply-patch.sh`(Phase 2 git-safe 적용). 메인 에이전트는 SKILL.md를 따라 ① 빌더 실행 → ② 서브에이전트 디스패치 → ③ Proposal을 한 건씩 사용자 승인 + Edit + 개별 commit.

**Tech Stack:** TypeScript (Bun 런타임), Bash, BATS (테스트), jq (검증)

**Spec:** `docs/superpowers/specs/2026-05-27-evolve-skill-design.md`

---

## File Structure

생성/수정 대상:

- **Create**: `plugins/me/skills/evolve/SKILL.md` — 메인 흐름 정의 (Phase 0/1/2 지시서)
- **Create**: `plugins/me/skills/evolve/scripts/build-index.ts` — Phase 0 TS 인덱스 빌더
- **Create**: `plugins/me/skills/evolve/scripts/apply-patch.sh` — Phase 2 git-safe 적용 헬퍼 (dirty 체크, 외부 캐시 차단, 개별 commit)
- **Create**: `tests/me/evolve-build-index.bats` — 인덱서 단위 테스트
- **Create**: `tests/me/evolve-skill.bats` — 스킬 구조 테스트 (frontmatter, 파일 존재, executable 비트)
- **Create**: `tests/fixtures/evolve/sample-session.jsonl` — 테스트용 미니 transcript
- **Modify**: `tests/me/me-specific.bats` — evolve 스킬 등록 검증 한 줄 추가

각 파일은 단일 책임:
- `SKILL.md`: 메인 에이전트가 따를 흐름 (코드 없음, 지시문만)
- `build-index.ts`: jsonl → SessionIndex JSON 변환 로직 전부
- `apply-patch.sh`: 안전 가드와 개별 commit (메인 에이전트가 호출)
- 테스트는 인덱서 동작과 스킬 구조 각각 검증

---

## Task 1: 스킬 디렉토리 + 테스트 fixture

**Files:**
- Create: `plugins/me/skills/evolve/` (디렉토리)
- Create: `plugins/me/skills/evolve/scripts/` (디렉토리)
- Create: `tests/fixtures/evolve/sample-session.jsonl`

- [ ] **Step 1: 디렉토리 생성**

```bash
mkdir -p plugins/me/skills/evolve/scripts
mkdir -p tests/fixtures/evolve
```

- [ ] **Step 2: 테스트 fixture 작성**

`tests/fixtures/evolve/sample-session.jsonl` 파일을 정확히 다음 내용으로 작성한다. 각 줄이 하나의 JSON 객체이며 줄바꿈 외 공백 없음.

```jsonl
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"/me:browse 잘 동작해?"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"확인하겠습니다."},{"type":"tool_use","name":"Bash","input":{"command":"grep -r foo src/"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"x","content":"no matches"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"grep -r foo lib/"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"y","content":"no matches"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Bash","input":{"command":"grep -r foo plugins/"}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"아니 그게 아니라 @plugins/me/skills/browse/ 봐"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"plugins/me/skills/browse/SKILL.md"}}],"stop_reason":"end_turn"}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"좋아 그거야"}]}}
```

이 fixture는 의도적으로 다음 신호를 포함:
- turn 7: user_correction ("아니 그게 아니라")
- turn 2,4,6: verbose_exploration (같은 `grep -r foo` 3회)
- turn 9: success_pattern ("좋아")

- [ ] **Step 3: 디렉토리 생성 확인 commit**

```bash
git add tests/fixtures/evolve/sample-session.jsonl
git commit -m "test(me/evolve): add transcript fixture for evolve skill"
```

---

## Task 2: build-index.ts — 타입 정의와 jsonl 로더

**Files:**
- Create: `plugins/me/skills/evolve/scripts/build-index.ts`

- [ ] **Step 1: 파일 골격 작성 (타입 + main 진입점 stub)**

`plugins/me/skills/evolve/scripts/build-index.ts` 파일을 다음 내용으로 작성한다:

```typescript
#!/usr/bin/env bun
// build-index.ts — transcript jsonl을 SessionIndex JSON으로 변환
// 사용: bun build-index.ts <jsonl-path> [--skill <name>]
// 출력: stdout에 JSON

import { readFileSync } from "node:fs";
import { basename } from "node:path";

// ── 타입 ───────────────────────────────────────────────
type SignalKind =
  | "user_correction"
  | "verbose_exploration"
  | "success_pattern"
  | "interrupt";

interface Signal {
  id: string;
  kind: SignalKind;
  turn_range: [number, number];
  snippet: string;
  detail?: string;
  context_pointer: { jsonl_path: string; turn_range: [number, number] };
}

interface TurnGroup {
  turn_range: [number, number];
  topic_hint: string;
  tools_used: Record<string, number>;
  signals: Signal[];
}

interface SkillInvocation {
  name: string;
  turn: number;
  outcome: string;
}

interface SessionIndex {
  session_id: string;
  jsonl_path: string;
  turns_total: number;
  user_messages: number;
  interrupts_total: number;
  tools_top: Array<[string, number]>;
  skill_invocations: SkillInvocation[];
  groups: TurnGroup[];
}

// ── 입력 파싱 ──────────────────────────────────────────
interface Turn {
  index: number;
  type: "user" | "assistant" | "other";
  userText?: string;
  toolUses: Array<{ name: string; input: any }>;
  interrupted: boolean;
  raw: any;
}

function loadTurns(jsonlPath: string): Turn[] {
  const lines = readFileSync(jsonlPath, "utf8").split("\n").filter(Boolean);
  const turns: Turn[] = [];
  for (let i = 0; i < lines.length; i++) {
    const obj = JSON.parse(lines[i]);
    if (obj.type !== "user" && obj.type !== "assistant") continue;
    const t: Turn = {
      index: turns.length + 1,
      type: obj.type,
      toolUses: [],
      interrupted: obj.message?.stop_reason === "interrupted",
      raw: obj,
    };
    const content = obj.message?.content;
    if (obj.type === "user") {
      if (typeof content === "string") t.userText = content;
      else if (Array.isArray(content) && content[0]?.type === "text") t.userText = content[0].text;
    } else {
      if (Array.isArray(content)) {
        for (const c of content) if (c.type === "tool_use") t.toolUses.push({ name: c.name, input: c.input });
      }
    }
    turns.push(t);
  }
  return turns;
}

// ── stub: 나머지는 후속 task에서 채움 ──────────────────
function buildIndex(jsonlPath: string, skillFilter?: string): SessionIndex {
  const turns = loadTurns(jsonlPath);
  return {
    session_id: basename(jsonlPath, ".jsonl"),
    jsonl_path: jsonlPath,
    turns_total: turns.length,
    user_messages: turns.filter((t) => t.userText !== undefined).length,
    interrupts_total: turns.filter((t) => t.interrupted).length,
    tools_top: [],
    skill_invocations: [],
    groups: [],
  };
}

// ── 진입점 ─────────────────────────────────────────────
function parseArgs(argv: string[]): { path: string; skill?: string } {
  const args = argv.slice(2);
  let path = "";
  let skill: string | undefined;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--skill") skill = args[++i];
    else path = args[i];
  }
  if (!path) {
    console.error("usage: bun build-index.ts <jsonl-path> [--skill <name>]");
    process.exit(2);
  }
  return { path, skill };
}

const { path, skill } = parseArgs(process.argv);
console.log(JSON.stringify(buildIndex(path, skill), null, 2));
```

- [ ] **Step 2: 실행 가능 비트 부여**

```bash
chmod +x plugins/me/skills/evolve/scripts/build-index.ts
```

- [ ] **Step 3: stub 동작 확인 (수동 smoke)**

```bash
bun plugins/me/skills/evolve/scripts/build-index.ts tests/fixtures/evolve/sample-session.jsonl
```

기대 출력: `turns_total: 9`, `user_messages: 4`, `interrupts_total: 0`, 나머지는 빈 배열인 JSON. 다르면 loadTurns 로직 확인.

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts
git commit -m "feat(me/evolve): add jsonl loader skeleton for build-index"
```

---

## Task 3: build-index 단위 테스트 (TDD 시작)

**Files:**
- Create: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: 첫 실패 테스트 작성 — 기본 카운트**

`tests/me/evolve-build-index.bats`를 다음 내용으로 작성한다:

```bash
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
    echo "$output" | jq -e '.user_messages == 4'
}
```

- [ ] **Step 2: 테스트 실행 → 통과 확인 (Task 2 stub이 이 케이스는 이미 만족)**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 1 test, 1 pass. 실패하면 Task 2 loadTurns 디버깅.

- [ ] **Step 3: 실패 테스트 추가 — user_correction 검출**

같은 파일에 추가:

```bash
@test "evolve build-index: detects user_correction signal" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "user_correction")] | length >= 1'
}
```

- [ ] **Step 4: 테스트 실행 → 실패 확인**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 첫 테스트 pass, 두 번째 FAIL (`groups`가 빈 배열이라 select가 빈 결과).

- [ ] **Step 5: Commit (failing test)**

```bash
git add tests/me/evolve-build-index.bats
git commit -m "test(me/evolve): add failing tests for build-index counts and corrections"
```

---

## Task 4: user_correction 신호 추출 구현

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts`

- [ ] **Step 1: 패턴 매칭 함수 추가**

`build-index.ts`의 `// ── stub` 주석 위(즉 `loadTurns` 함수 바로 아래)에 다음을 추가한다:

```typescript
// ── 신호 추출: A. user_correction ──────────────────────
const CORRECTION_KR = /^(아니|그게 아니|그러지 말|다시|잠깐)/;
const CORRECTION_EN = /\b(no|stop|wait|hold on|don't|that's not)\b/i;
const PATH_REDIRECT = /@\S+\//;

function extractUserCorrections(turns: Turn[], jsonlPath: string): Signal[] {
  const signals: Signal[] = [];
  let counter = 0;
  for (const t of turns) {
    if (!t.userText) continue;
    const text = t.userText.trim();
    const matched =
      CORRECTION_KR.test(text) || CORRECTION_EN.test(text) || PATH_REDIRECT.test(text);
    if (!matched) continue;
    counter++;
    signals.push({
      id: `S${counter}`,
      kind: "user_correction",
      turn_range: [t.index, t.index],
      snippet: text.slice(0, 80),
      context_pointer: { jsonl_path: jsonlPath, turn_range: [Math.max(1, t.index - 2), t.index] },
    });
  }
  return signals;
}
```

- [ ] **Step 2: buildIndex에서 호출하고 단일 group으로 묶기 (임시)**

`buildIndex` 함수를 다음과 같이 교체한다:

```typescript
function buildIndex(jsonlPath: string, skillFilter?: string): SessionIndex {
  const turns = loadTurns(jsonlPath);
  const corrections = extractUserCorrections(turns, jsonlPath);
  const groups: TurnGroup[] =
    corrections.length === 0
      ? []
      : [
          {
            turn_range: [1, turns.length],
            topic_hint: "session",
            tools_used: {},
            signals: corrections,
          },
        ];
  return {
    session_id: basename(jsonlPath, ".jsonl"),
    jsonl_path: jsonlPath,
    turns_total: turns.length,
    user_messages: turns.filter((t) => t.userText !== undefined).length,
    interrupts_total: turns.filter((t) => t.interrupted).length,
    tools_top: [],
    skill_invocations: [],
    groups,
  };
}
```

- [ ] **Step 3: 테스트 통과 확인**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 2 tests, 2 pass.

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts
git commit -m "feat(me/evolve): detect user_correction signals"
```

---

## Task 5: verbose_exploration 신호 추출

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts`
- Modify: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: 실패 테스트 추가**

`tests/me/evolve-build-index.bats`에 추가:

```bash
@test "evolve build-index: detects verbose_exploration (repeated grep)" {
    run bun "$INDEXER" "$FIXTURE"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.groups[].signals[] | select(.kind == "verbose_exploration")] | length >= 1'
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
bats tests/me/evolve-build-index.bats --filter "verbose_exploration"
```

기대: FAIL.

- [ ] **Step 3: extractVerboseExploration 구현**

`extractUserCorrections` 함수 아래에 추가:

```typescript
// ── 신호 추출: C. verbose_exploration ──────────────────
function extractVerboseExploration(turns: Turn[], jsonlPath: string, startId: number): Signal[] {
  const signals: Signal[] = [];
  let counter = startId;
  // 같은 Bash command prefix 3회 이상 또는 같은 Read file_path 3회 이상을 찾는다
  const bashCounts = new Map<string, number[]>();   // prefix → turn 번호 목록
  const readCounts = new Map<string, number[]>();   // file_path → turn 번호 목록
  for (const t of turns) {
    for (const tu of t.toolUses) {
      if (tu.name === "Bash") {
        const cmd: string = tu.input?.command ?? "";
        const prefix = cmd.split(/\s+/).slice(0, 2).join(" "); // 예: "grep -r"
        if (!prefix) continue;
        if (!bashCounts.has(prefix)) bashCounts.set(prefix, []);
        bashCounts.get(prefix)!.push(t.index);
      } else if (tu.name === "Read") {
        const path: string = tu.input?.file_path ?? "";
        if (!path) continue;
        if (!readCounts.has(path)) readCounts.set(path, []);
        readCounts.get(path)!.push(t.index);
      }
    }
  }
  for (const [prefix, turnsList] of bashCounts) {
    if (turnsList.length < 3) continue;
    counter++;
    signals.push({
      id: `S${counter}`,
      kind: "verbose_exploration",
      turn_range: [turnsList[0], turnsList[turnsList.length - 1]],
      snippet: prefix,
      detail: `같은 명령 ${turnsList.length}회 반복`,
      context_pointer: { jsonl_path: jsonlPath, turn_range: [turnsList[0], turnsList[turnsList.length - 1]] },
    });
  }
  for (const [path, turnsList] of readCounts) {
    if (turnsList.length < 3) continue;
    counter++;
    signals.push({
      id: `S${counter}`,
      kind: "verbose_exploration",
      turn_range: [turnsList[0], turnsList[turnsList.length - 1]],
      snippet: path,
      detail: `같은 파일 Read ${turnsList.length}회`,
      context_pointer: { jsonl_path: jsonlPath, turn_range: [turnsList[0], turnsList[turnsList.length - 1]] },
    });
  }
  return signals;
}
```

- [ ] **Step 4: buildIndex에서 호출하여 signals 병합**

`buildIndex` 함수의 `corrections` 줄 아래에 다음을 추가하고, groups 배열 구성 코드를 교체한다:

```typescript
  const verbose = extractVerboseExploration(turns, jsonlPath, corrections.length);
  const allSignals = [...corrections, ...verbose];
  const groups: TurnGroup[] =
    allSignals.length === 0
      ? []
      : [
          {
            turn_range: [1, turns.length],
            topic_hint: "session",
            tools_used: {},
            signals: allSignals,
          },
        ];
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 3 tests, 3 pass.

- [ ] **Step 6: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts tests/me/evolve-build-index.bats
git commit -m "feat(me/evolve): detect verbose_exploration signals"
```

---

## Task 6: success_pattern + interrupt 신호 + tools_top 통계

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts`
- Modify: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: 실패 테스트 추가**

```bash
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
```

- [ ] **Step 2: 실패 확인**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 2개 신규 FAIL.

- [ ] **Step 3: success_pattern 추출 함수 추가**

```typescript
// ── 신호 추출: D. success_pattern ──────────────────────
const POSITIVE = /^(좋아|perfect|그렇지|yes|ok|good|great)\b/i;

function extractSuccessPatterns(turns: Turn[], jsonlPath: string, startId: number): Signal[] {
  const signals: Signal[] = [];
  let counter = startId;
  for (const t of turns) {
    if (!t.userText || !POSITIVE.test(t.userText.trim())) continue;
    counter++;
    const winStart = Math.max(1, t.index - 5);
    signals.push({
      id: `S${counter}`,
      kind: "success_pattern",
      turn_range: [winStart, t.index],
      snippet: t.userText.trim().slice(0, 80),
      context_pointer: { jsonl_path: jsonlPath, turn_range: [winStart, t.index] },
    });
  }
  return signals;
}
```

- [ ] **Step 4: tools_top 통계 함수 추가**

```typescript
// ── 통계: tools_top ────────────────────────────────────
function buildToolsTop(turns: Turn[]): Array<[string, number]> {
  const counts = new Map<string, number>();
  for (const t of turns) for (const tu of t.toolUses) counts.set(tu.name, (counts.get(tu.name) ?? 0) + 1);
  return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10);
}
```

- [ ] **Step 5: buildIndex 갱신 (성공·도구통계 반영)**

`buildIndex` 안의 신호 수집부를 다음으로 교체:

```typescript
  const corrections = extractUserCorrections(turns, jsonlPath);
  const verbose = extractVerboseExploration(turns, jsonlPath, corrections.length);
  const success = extractSuccessPatterns(turns, jsonlPath, corrections.length + verbose.length);
  const allSignals = [...corrections, ...verbose, ...success];
```

그리고 return 객체의 `tools_top: [],` 를 `tools_top: buildToolsTop(turns),`로 교체.

- [ ] **Step 6: 테스트 통과 확인**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 5 tests, 5 pass.

- [ ] **Step 7: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts tests/me/evolve-build-index.bats
git commit -m "feat(me/evolve): detect success_pattern and emit tools_top"
```

---

## Task 7: 슬래시 커맨드 invocations + group 분할 + skill 필터

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts`
- Modify: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: 실패 테스트 추가**

```bash
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
```

- [ ] **Step 2: 실패 확인**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 2개 신규 FAIL.

- [ ] **Step 3: 슬래시 커맨드 추출 추가**

```typescript
// ── skill invocations ──────────────────────────────────
const SLASH_CMD = /^\/([a-z0-9:_-]+)\b/i;

function extractSkillInvocations(turns: Turn[]): SkillInvocation[] {
  const invs: SkillInvocation[] = [];
  for (const t of turns) {
    if (!t.userText) continue;
    const m = t.userText.trim().match(SLASH_CMD);
    if (!m) continue;
    invs.push({ name: m[1], turn: t.index, outcome: "completed" });
  }
  return invs;
}
```

- [ ] **Step 4: 그룹 분할 함수 추가**

```typescript
// ── group 분할: 슬래시 커맨드 경계로 자름 ──────────────
function splitGroups(
  turns: Turn[],
  invs: SkillInvocation[],
  allSignals: Signal[],
): TurnGroup[] {
  if (turns.length === 0) return [];
  const boundaries = [1, ...invs.map((i) => i.turn), turns.length + 1];
  const uniqSorted = [...new Set(boundaries)].sort((a, b) => a - b);
  const groups: TurnGroup[] = [];
  for (let i = 0; i < uniqSorted.length - 1; i++) {
    const start = uniqSorted[i];
    const end = uniqSorted[i + 1] - 1;
    const groupSignals = allSignals.filter(
      (s) => s.turn_range[0] >= start && s.turn_range[1] <= end,
    );
    if (groupSignals.length === 0) continue;
    const tools: Record<string, number> = {};
    for (const t of turns) {
      if (t.index < start || t.index > end) continue;
      for (const tu of t.toolUses) tools[tu.name] = (tools[tu.name] ?? 0) + 1;
    }
    const inv = invs.find((i) => i.turn >= start && i.turn <= end);
    groups.push({
      turn_range: [start, end],
      topic_hint: inv ? `/${inv.name} 호출 구간` : "session",
      tools_used: tools,
      signals: groupSignals,
    });
  }
  return groups;
}
```

- [ ] **Step 5: buildIndex 갱신 (skillFilter 적용)**

`buildIndex`를 다음으로 교체:

```typescript
function buildIndex(jsonlPath: string, skillFilter?: string): SessionIndex {
  const turns = loadTurns(jsonlPath);
  const corrections = extractUserCorrections(turns, jsonlPath);
  const verbose = extractVerboseExploration(turns, jsonlPath, corrections.length);
  const success = extractSuccessPatterns(turns, jsonlPath, corrections.length + verbose.length);
  const allSignals = [...corrections, ...verbose, ...success];
  let invs = extractSkillInvocations(turns);
  let groups = splitGroups(turns, invs, allSignals);
  if (skillFilter) {
    invs = invs.filter((i) => i.name === skillFilter);
    const allowed = new Set(invs.map((i) => i.turn));
    groups = groups.filter((g) =>
      [...allowed].some((t) => t >= g.turn_range[0] && t <= g.turn_range[1]),
    );
  }
  return {
    session_id: basename(jsonlPath, ".jsonl"),
    jsonl_path: jsonlPath,
    turns_total: turns.length,
    user_messages: turns.filter((t) => t.userText !== undefined).length,
    interrupts_total: turns.filter((t) => t.interrupted).length,
    tools_top: buildToolsTop(turns),
    skill_invocations: invs,
    groups,
  };
}
```

- [ ] **Step 6: 테스트 통과 확인**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 7 tests, 7 pass.

- [ ] **Step 7: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts tests/me/evolve-build-index.bats
git commit -m "feat(me/evolve): split groups by slash-command and support --skill filter"
```

---

## Task 8: apply-patch.sh — git-safe 적용 헬퍼

**Files:**
- Create: `plugins/me/skills/evolve/scripts/apply-patch.sh`

- [ ] **Step 1: 스크립트 작성**

`plugins/me/skills/evolve/scripts/apply-patch.sh` 파일을 다음 내용으로 작성한다:

```bash
#!/usr/bin/env bash
# apply-patch.sh — Phase 2 git-safe 적용 헬퍼
# 사용: apply-patch.sh <target-file> <patch-file> <commit-subject> <signal-snippet> <session-id>
# 동작: 외부 캐시 차단 → patch 적용 → 단일 commit
# 종료 코드: 0=적용, 10=외부 캐시 차단, 11=patch 실패, 12=dirty tree

set -euo pipefail

target="${1:?target-file required}"
patch="${2:?patch-file required}"
subject="${3:?commit-subject required}"
snippet="${4:?signal-snippet required}"
session="${5:?session-id required}"

# 1. 외부 캐시 차단
case "$target" in
    "$HOME"/.claude/plugins/cache/*)
        echo "blocked: external plugin cache cannot be modified directly" >&2
        echo "target: $target" >&2
        exit 10
        ;;
esac

# 2. dirty tree 차단 (target과 무관하게)
if [ -n "$(git status --porcelain)" ]; then
    echo "blocked: working tree is dirty. commit or stash first." >&2
    git status --short >&2
    exit 12
fi

# 3. patch 적용
if ! git apply --check "$patch" 2>/dev/null; then
    echo "blocked: patch does not apply cleanly" >&2
    git apply --check "$patch" >&2 || true
    exit 11
fi
git apply "$patch"

# 4. commit
git add "$target"
git commit -m "$(printf 'evolve: %s\n\nSignal: %s\nSession: %s\n' "$subject" "$snippet" "$session")"

# 5. 새 commit sha 출력 (메인 에이전트가 캡처)
git rev-parse --short HEAD
```

- [ ] **Step 2: 실행 가능 비트 부여**

```bash
chmod +x plugins/me/skills/evolve/scripts/apply-patch.sh
```

- [ ] **Step 3: 외부 캐시 차단 수동 확인**

```bash
echo "" > /tmp/empty.patch
plugins/me/skills/evolve/scripts/apply-patch.sh \
  "$HOME/.claude/plugins/cache/foo/SKILL.md" /tmp/empty.patch "test" "test snippet" "test-id"
echo "exit: $?"
```

기대: stderr에 "blocked: external plugin cache..." 출력, exit 10.

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/evolve/scripts/apply-patch.sh
git commit -m "feat(me/evolve): add git-safe apply-patch helper with cache block"
```

---

## Task 9: SKILL.md 작성

**Files:**
- Create: `plugins/me/skills/evolve/SKILL.md`

- [ ] **Step 1: SKILL.md 작성**

`plugins/me/skills/evolve/SKILL.md` 파일을 다음 내용으로 작성한다:

````markdown
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
/me:evolve me:research              해당 스킬에 집중
/me:evolve --session <id>           특정 세션 ID
/me:evolve --since 7d me:browse     7일치 + 스킬 필터
/me:evolve --dry-run                제안만, 적용 안 함
```

## What this skill does NOT do

- raw transcript를 메인 에이전트가 직접 읽지 않는다 (컨텍스트 폭발 방지)
- 외부 플러그인 캐시(`~/.claude/plugins/cache/`)는 수정 안 한다 (upstream 제안 파일에만 누적)
- 새 스킬을 만들지 않는다 (`writing-skills` 영역)
- 자동 commit·push 안 한다 (반드시 사용자가 한 건씩 승인)

## Phase 0 — 인덱스 빌드 (Bash)

1. 현재 세션의 transcript 경로를 결정:
   - 인자 `--session <id>` 있으면 그 id 사용
   - 없으면 환경 변수 `CLAUDE_SESSION_ID` 또는 `~/.claude/projects/<encoded-cwd>/`에서 가장 최근 `.jsonl`
   - encoded-cwd는 `pwd | sed 's|/|-|g'`
2. dirty tree 가드:

   ```bash
   git status --porcelain | grep -q . && { echo "dirty tree, abort"; exit 1; }
   ```

3. 인덱서 실행:

   ```bash
   bun "${CLAUDE_PLUGIN_ROOT}/skills/evolve/scripts/build-index.ts" <jsonl-path> [--skill <name>]
   ```

   stdout JSON을 변수에 캡처. **사용자에게 보여주지 말 것** — 다음 단계 서브에이전트에게만 전달.

4. 인덱스의 `groups`가 비었으면: "이 세션에서는 개선 신호를 못 찾았어요" 출력 후 종료.

## Phase 1 — 서브에이전트 분석 (Agent)

서브에이전트(`general-purpose`)를 1개 디스패치한다. 프롬프트에 다음을 모두 포함:

1. spec 경로: `docs/superpowers/specs/2026-05-27-evolve-skill-design.md`
2. Phase 0에서 받은 인덱스 JSON 전체
3. 후보 파일 매핑 표 (아래 그대로 복사):

   | 신호 패턴 | 1순위 후보 | 2순위 |
   |---|---|---|
   | 스킬 미발견 / "이 스킬 안 쓰네" | 해당 SKILL.md (description, 트리거 키워드) | 가까운 AGENTS.md |
   | 스킬 invoke 후에도 규칙 위반 | 해당 SKILL.md (본문, Red Flags 섹션) | — |
   | 장황한 탐색 + 결국 X를 찾음 | 가까운 AGENTS.md (Key Files / Subdirectories) | CLAUDE.md |
   | 프로젝트 룰/관례 위반 | 가까운 CLAUDE.md | AGENTS.md |
   | 성공 패턴 | 자주 호출된 SKILL.md | — |

4. 출력 스키마: 아래 형식의 JSON 한 덩어리만, 다른 텍스트 없이.

   ```json
   {
     "proposals": [
       {
         "id": "P1",
         "signal_ids": ["S1"],
         "target_file": "<absolute path>",
         "is_external_cache": false,
         "change_kind": "edit",
         "patch": "<unified diff applicable with `git apply`>",
         "rationale": "1~2문장"
       }
     ],
     "skipped_signals": [{"id": "S3", "reason": "신뢰도 낮음"}]
   }
   ```

5. 지시: "트리만 보고 시작. 필요할 때만 `Bash`로 jsonl의 해당 turn 범위를 발췌해 깊이 분석. 메인 transcript는 절대 통째 읽지 말 것. 결과 JSON만 반환."

## Phase 2 — 적용 루프

서브에이전트 반환 JSON 파싱 후:

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
   - **y**: patch를 임시 파일에 쓰고 `apply-patch.sh` 호출:

     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/skills/evolve/scripts/apply-patch.sh" \
       "<target_file>" "<patch-file>" "<subject>" "<snippet>" "<session-id>"
     ```

     stdout의 short sha를 누적 목록에 기록.
   - **edit**: 사용자에게 patch 편집 기회 제공 후 y와 동일하게 처리.
   - **skip / n**: 다음 proposal로.

4. `--dry-run` 인자가 있으면 Phase 2 전체 스킵, proposal 목록만 출력.

5. 마무리: 적용된 commit sha 목록과 upstream 파일 경로 출력.

## Safety

- 시작 시 `git status --porcelain`이 비어 있어야 함 (dirty면 거부)
- 외부 캐시 차단은 `apply-patch.sh`가 한 번 더 강제 (이중 가드)
- patch는 적용 전 반드시 사용자에게 diff로 보여주기
- 각 변경은 별도 commit → `git revert <sha>` 한 줄로 개별 롤백 가능
````

- [ ] **Step 2: 빠른 구조 확인**

```bash
head -8 plugins/me/skills/evolve/SKILL.md
```

기대: `---`로 시작하는 frontmatter, `name: evolve`, `description: Use when asked to "evolve skill"...` 줄 포함.

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/evolve/SKILL.md
git commit -m "feat(me/evolve): add SKILL.md with phase 0/1/2 instructions"
```

---

## Task 10: 스킬 구조 테스트 + me-specific.bats 등록

**Files:**
- Create: `tests/me/evolve-skill.bats`
- Modify: `tests/me/me-specific.bats`

- [ ] **Step 1: evolve-skill.bats 작성**

`tests/me/evolve-skill.bats`를 다음 내용으로 작성한다:

```bash
#!/usr/bin/env bats
# /me:evolve 스킬 구조 검증

bats_require_minimum_version 1.5.0
load ../helpers/bats_helper

@test "evolve: skill files exist" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/apply-patch.sh" ]
}

@test "evolve: SKILL.md has proper frontmatter" {
    local f="${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md"
    has_frontmatter_delimiter "$f"
    has_frontmatter_field "$f" "name"
    has_frontmatter_field "$f" "description"
}

@test "evolve: scripts are executable" {
    [ -x "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
    [ -x "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/apply-patch.sh" ]
}

@test "evolve: apply-patch.sh blocks external cache writes" {
    local script="${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/apply-patch.sh"
    local patch="$BATS_TEST_TMPDIR/empty.patch"
    : > "$patch"
    run "$script" "$HOME/.claude/plugins/cache/foo/SKILL.md" "$patch" "x" "y" "z"
    [ "$status" -eq 10 ]
    [[ "$output" =~ "external plugin cache" ]] || [[ "$stderr" =~ "external plugin cache" ]]
}
```

- [ ] **Step 2: me-specific.bats에 등록 테스트 한 줄 추가**

`tests/me/me-specific.bats`에서 `"me: lifecycle skills include build, test, review, and ship"` 테스트 바로 아래에 다음 블록을 추가한다:

```bash
@test "me: evolve skill exists" {
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/SKILL.md" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/build-index.ts" ]
    [ -f "${PROJECT_ROOT}/plugins/me/skills/evolve/scripts/apply-patch.sh" ]
}
```

- [ ] **Step 3: 테스트 실행**

```bash
bats tests/me/evolve-skill.bats tests/me/me-specific.bats
```

기대: 모든 evolve 테스트 pass, 기존 me-specific 테스트도 그대로 pass.

- [ ] **Step 4: Commit**

```bash
git add tests/me/evolve-skill.bats tests/me/me-specific.bats
git commit -m "test(me/evolve): add skill structure tests"
```

---

## Task 11: 통합 smoke 테스트 — fixture를 끝에서 끝까지 인덱싱

**Files:**
- Modify: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: 통합 smoke 테스트 추가**

`tests/me/evolve-build-index.bats` 끝에 추가:

```bash
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
```

- [ ] **Step 2: 테스트 실행**

```bash
bats tests/me/evolve-build-index.bats
```

기대: 8 tests, 8 pass.

- [ ] **Step 3: 전체 me 테스트 회귀 확인**

```bash
bats tests/me/
```

기대: 기존 테스트 모두 pass + evolve 신규 테스트 모두 pass.

- [ ] **Step 4: Commit**

```bash
git add tests/me/evolve-build-index.bats
git commit -m "test(me/evolve): add end-to-end smoke test on fixture"
```

---

## Task 12: pre-commit 전체 회귀 + 최종 검토

- [ ] **Step 1: pre-commit hooks 전체 실행**

```bash
pre-commit run --all-files
```

기대: 모든 hook pass. 실패하는 hook이 있으면 해당 파일을 수정 후 재실행.

- [ ] **Step 2: 전체 bats 회귀**

```bash
bats tests/
```

기대: 모든 테스트 pass. 실패하면 무엇이 깨졌는지 진단 후 해당 task로 돌아가 수정.

- [ ] **Step 3: SKILL.md를 한 번 사람 눈으로 읽으며 검증**

확인 사항:
- frontmatter `name: evolve`, `description: Use when asked to "evolve skill"...` 일관
- Phase 0/1/2 흐름이 spec과 일치
- 외부 캐시 차단이 SKILL.md와 apply-patch.sh 양쪽에 명시되어 있음
- `--dry-run` 흐름이 명시

이상 있으면 SKILL.md만 수정 → Commit.

- [ ] **Step 4: 최종 commit이 필요하면**

```bash
git add -A
git commit -m "chore(me/evolve): final review touch-ups"
```

필요 없으면 스킵.

---

## Self-Review (작성자 메모, 실행 전 확인용)

**Spec coverage 매핑:**
- 합의된 원칙 6개 → Task 9 SKILL.md "What this skill does NOT do" + Task 8 apply-patch.sh로 강제
- Phase 0 (인덱스 빌더 + 트리 스키마 + 신호 추출 4종 + group 분할 + skill 필터) → Task 2~7
- Phase 1 (서브에이전트 분석 + 후보 매핑 표 + 출력 스키마) → Task 9 SKILL.md
- Phase 2 (proposal 루프 + 개별 commit + upstream-only 분리) → Task 9 SKILL.md + Task 8 apply-patch.sh
- 안전 가드 4종(외부 캐시 / dirty tree / dry-run / 개별 commit / patch 미리보기) → Task 8 + Task 9

**Type consistency:**
- `SessionIndex` / `Signal` / `TurnGroup` / `SkillInvocation` 이름이 Task 2에서 정의되어 Task 4~7에서 일관 사용
- `apply-patch.sh` 인자 순서 `target, patch, subject, snippet, session`이 Task 8 정의 → Task 9 SKILL.md 호출부 일치

**Placeholder 스캔:** TBD / "implement later" / "similar to" 없음.

**알려진 빈자리(의도적):**
- 인덱스 빌더의 "현재 세션 ID 자동 탐지"는 SKILL.md에서 `CLAUDE_SESSION_ID` 또는 가장 최근 .jsonl 사용으로 우회 — 정확한 ID 식별은 환경에 따라 다르므로 SKILL.md가 사용자에게 묻거나 추정한다
- `topic_hint` 자동 추정은 슬래시 커맨드 경계만 사용 (그 외 50턴 윈도우 분할은 spec에 있으나 1차 구현 범위 밖 — 필요해지면 후속 task)
