# evolve `--recent` 멀티세션 검토 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `build-index.ts`에 `--recent [N]` 플래그를 추가해, 최근 N개 세션의 transcript를 모아 skill별로 신호를 집계하되 "세션 호출 이후 본문이 이미 바뀐 skill"(stale)은 본문 해시 비교로 가려 제외하는 멀티세션 인덱스를 출력한다.

**Architecture:** 기존 단일세션 경로(`buildIndex` → 단일 `SessionIndex` JSON)는 그대로 둔다. `--recent`가 주어지면 별도 경로(`buildRecentIndex`)가 프로젝트 디렉터리에서 mtime 상위 N개 jsonl을 골라 각각 `loadTurns`/`buildEvents`로 인덱싱하고, skill 호출마다 jsonl에 보존된 호출시점 본문(`isMeta:true` 메시지, `sourceToolUseID`로 연결)의 해시를 현재 디스크 SKILL.md 본문 해시와 비교한다. 다르면 그 skill을 제외(`dropped`)하고, 살아남은 skill의 events만 묶어 멀티세션 JSON으로 출력한다.

**Tech Stack:** TypeScript (Bun runtime), `node:crypto`의 `createHash`, BATS + fixture jsonl + jq.

---

## File Structure

- **Modify:** `plugins/me/skills/evolve/scripts/build-index.ts`
  - `loadTurns`를 확장해 skill 호출시점 주입 본문(`isMeta`)을 캡처 (`SkillInvocation[]` 반환 추가).
  - 본문 정규화 + 해시 헬퍼 추가 (`stripBaseDirLine`, `stripFrontmatter`, `bodyHash`).
  - `--recent [N]` 인자 파싱, 세션 N개 선정(`recentSessionPaths`), 멀티세션 인덱스 빌드(`buildRecentIndex`), `--recent`/`--session` 모순 거부.
  - 진입점에서 `recent` 여부로 단일/멀티 분기.
- **Create:** `tests/fixtures/evolve/skill-invocation-session.jsonl` — Skill tool_use + `isMeta` 주입 본문을 가진 fixture.
- **Modify:** `tests/me/evolve-build-index.bats` — `--recent` 동작 테스트 추가.
- **Modify:** `plugins/me/skills/evolve/SKILL.md` — `--recent` 문서화, 멀티세션 인덱스 스키마와 stale 규칙을 Phase 0/1에 반영.

> **Language rule (이 repo 관습):** 모든 skill 스크립트는 TypeScript(Bun)다. shell/Python 대안 금지.
> **Forbidden:** `build-index.ts`에 규칙 기반 분류(regex/keyword) 추가 금지. 분류는 Phase 1 LLM이 한다. 이 계획은 결정론적 메타데이터(해시/skill 이름/events)만 다룬다.

---

## Task 1: 본문 정규화 + 해시 헬퍼

전제: stale 판정은 "호출시점 본문"과 "현재 디스크 본문"을 같은 정규화 규칙으로 해시해 비교한다.
- transcript 주입 본문: 첫 줄 `Base directory for this skill: …` + 뒤따르는 빈 줄 제거. frontmatter는 이미 없음.
- 디스크 SKILL.md: YAML frontmatter(`---`…`---`) 제거.
- 양쪽 모두 끝 공백 제거(`trimEnd`) 후 sha256.

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts` (import 1줄 + 헬퍼 3개)
- Test: `tests/me/evolve-build-index.bats` (헬퍼는 내부 함수라 BATS 직접 검증 불가 → Task 4의 통합 fixture로 간접 검증. 이 Task는 컴파일/실행 무결성만 확인)

- [ ] **Step 1: import에 createHash 추가**

`build-index.ts` 상단 import 블록(현재 line 6-8)에 한 줄 추가:

```typescript
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { homedir } from "node:os";
import { createHash } from "node:crypto";
```

- [ ] **Step 2: 정규화 + 해시 헬퍼 추가**

`summarizeToolUse` 함수 정의 바로 앞(현재 line 119 `// ── tool_use 요약` 주석 위)에 삽입:

```typescript
// ── skill 본문 정규화 + 해시 (stale 판정용) ──
const BASE_DIR_LINE = /^Base directory for this skill:.*(?:\r?\n)+/;

// transcript 주입 본문에서 "Base directory" 첫 줄(+뒤 빈 줄) 제거
function stripBaseDirLine(injected: string): string {
  return injected.replace(BASE_DIR_LINE, "");
}

// 디스크 SKILL.md에서 YAML frontmatter(--- … ---) 제거
function stripFrontmatter(raw: string): string {
  if (!raw.startsWith("---")) return raw;
  const end = raw.indexOf("\n---", 3);
  if (end === -1) return raw;
  const after = raw.indexOf("\n", end + 1);
  return after === -1 ? "" : raw.slice(after + 1);
}

function bodyHash(body: string): string {
  return createHash("sha256").update(body.trimEnd()).digest("hex");
}
```

- [ ] **Step 3: 컴파일/실행 무결성 확인 (기존 동작 회귀 없음)**

Run: `bun plugins/me/skills/evolve/scripts/build-index.ts tests/fixtures/evolve/sample-session.jsonl | jq -e '.turns == 9'`
Expected: `true` (기존 단일세션 출력 그대로, 헬퍼 추가가 깨뜨리지 않음)

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts
git commit -m "feat(evolve): add SKILL.md body normalization + hash helpers"
```

---

## Task 2: loadTurns가 skill 호출시점 주입 본문을 캡처

전제(subagent 검증): skill 호출 시 `type:"user"`, `isMeta:true`, `message.content[0].type:"text"` 메시지가 주입되며 첫 줄이 `Base directory for this skill: <abs path>`. 이 메시지의 `sourceToolUseID`가 Skill tool_use id와 일치. 디렉터리명 = skill 식별자.

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts` (`LoadedTranscript` 타입 + `loadTurns` 본문)
- Test: Task 4 통합 fixture로 검증

- [ ] **Step 1: SkillInvocation 타입 + LoadedTranscript 확장**

`LoadedTranscript` 인터페이스(현재 line 65-68)를 교체:

```typescript
interface SkillInvocation {
  name: string;          // skill 식별자 (Base directory의 마지막 디렉터리명)
  baseDir: string;       // 주입 본문의 Base directory 절대경로
  injectedBody: string;  // "Base directory" 줄 제거 후의 본문 (해시 입력)
}

interface LoadedTranscript {
  turns: Turn[];
  sessionTitle?: string;
  skillInvocations: SkillInvocation[];
}
```

- [ ] **Step 2: loadTurns에서 isMeta 주입 본문 파싱**

`loadTurns`(현재 line 78-117)를 교체. 변경점: `skillInvocations` 수집 + 반환 추가. 기존 turn 파싱 로직은 그대로 유지.

```typescript
function loadTurns(jsonlPath: string): LoadedTranscript {
  const lines = readFileSync(jsonlPath, "utf8").split("\n").filter(Boolean);
  const turns: Turn[] = [];
  const skillInvocations: SkillInvocation[] = [];
  let sessionTitle: string | undefined;
  for (const line of lines) {
    const obj = JSON.parse(line);
    if (obj.type === "ai-title" && typeof obj.aiTitle === "string") {
      sessionTitle = obj.aiTitle;
      continue;
    }
    // skill 호출시점 주입 본문 (isMeta user/text, 첫 줄 "Base directory for this skill:")
    if (obj.type === "user" && obj.isMeta === true) {
      const c = obj.message?.content;
      const text = Array.isArray(c) && c[0]?.type === "text" ? c[0].text : undefined;
      if (typeof text === "string") {
        const m = text.match(/^Base directory for this skill:\s*(.+?)\s*(?:\r?\n|$)/);
        if (m) {
          const baseDir = m[1];
          skillInvocations.push({
            name: basename(baseDir),
            baseDir,
            injectedBody: stripBaseDirLine(text),
          });
        }
      }
      continue; // 주입 메시지는 turn으로 세지 않음
    }
    if (obj.type !== "user" && obj.type !== "assistant") continue;
    const userInterruptedMarker = obj.interruptedMessageId !== undefined;
    const assistantInterruptedMarker = obj.message?.stop_reason === "interrupted";
    const t: Turn = {
      index: turns.length + 1,
      type: obj.type,
      toolUses: [],
      toolResults: [],
      interrupted: userInterruptedMarker || assistantInterruptedMarker,
      interruptedBy: userInterruptedMarker ? "user" : assistantInterruptedMarker ? "assistant" : undefined,
    };
    const content = obj.message?.content;
    if (obj.type === "user") {
      if (typeof content === "string") t.userText = content;
      else if (Array.isArray(content)) {
        if (content[0]?.type === "text") t.userText = content[0].text;
        for (const c of content) {
          if (c.type === "tool_result") {
            const norm = normalizeToolResultContent(c.content);
            t.toolResults.push({ content: norm, isError: c.is_error === true });
          }
        }
      }
    } else if (Array.isArray(content)) {
      for (const c of content) if (c.type === "tool_use") t.toolUses.push({ name: c.name, input: c.input });
    }
    turns.push(t);
  }
  return { turns, sessionTitle, skillInvocations };
}
```

- [ ] **Step 3: buildIndex의 구조분해 깨지지 않는지 확인**

`buildIndex`(현재 line 325-335)는 `const { turns, sessionTitle } = loadTurns(...)`로 구조분해한다. `skillInvocations`가 추가돼도 기존 분해는 그대로 동작(추가 필드 무시). 단일세션 출력은 변하지 않아야 한다.

Run: `bun plugins/me/skills/evolve/scripts/build-index.ts tests/fixtures/evolve/sample-session.jsonl | jq -e '(keys - ["session_id","session_title","turns","summary","events"]) == []'`
Expected: `true`

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts
git commit -m "feat(evolve): capture skill invocation bodies in loadTurns"
```

---

## Task 3: `--recent [N]` 인자 파싱 + 모순 거부

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts` (`parseArgs` + 진입점은 Task 5)
- Test: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: 실패하는 테스트 작성 (모순 플래그 거부)**

`tests/me/evolve-build-index.bats` 끝에 추가:

```bash
@test "evolve build-index: --recent and --session together exit 2" {
    run bun "$INDEXER" --recent --session abc
    [ "$status" -eq 2 ]
}

@test "evolve build-index: --recent with positional path exits 2" {
    run bun "$INDEXER" --recent "$FIXTURE"
    [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bats tests/me/evolve-build-index.bats -f "recent and --session"`
Expected: FAIL (현재 `--recent`는 미지원 플래그라 "unexpected argument"로 exit 2가 날 수도, positional로 먹힐 수도 있음 — 두 테스트 중 최소 하나 FAIL)

- [ ] **Step 3: parseArgs에 --recent 추가**

`parseArgs`(현재 line 370-383)를 교체:

```typescript
function parseArgs(argv: string[]): { jsonlPath?: string; sessionId?: string; recent?: number } {
  const args = argv.slice(2);
  let jsonlPath: string | undefined;
  let sessionId: string | undefined;
  let recent: number | undefined;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--session") sessionId = args[++i];
    else if (args[i] === "--recent") {
      // 다음 토큰이 양의 정수면 N, 아니면 기본 10
      const next = args[i + 1];
      if (next !== undefined && /^[1-9][0-9]*$/.test(next)) {
        recent = parseInt(next, 10);
        i++;
      } else {
        recent = 10;
      }
    } else if (!jsonlPath) jsonlPath = args[i];
    else {
      console.error(`unexpected argument: ${args[i]}`);
      process.exit(2);
    }
  }
  if (recent !== undefined && (sessionId !== undefined || jsonlPath !== undefined)) {
    console.error("--recent cannot be combined with --session or a transcript path");
    process.exit(2);
  }
  return { jsonlPath, sessionId, recent };
}
```

- [ ] **Step 4: 모순 거부 테스트 통과 확인**

Run: `bats tests/me/evolve-build-index.bats -f "recent"`
Expected: 두 모순 테스트 PASS (진입점 분기는 Task 5에서 — 이 단계에서 `--recent` 단독 실행은 아직 정상 인덱스를 내지 않을 수 있으나, 모순 케이스만 검증)

- [ ] **Step 5: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts tests/me/evolve-build-index.bats
git commit -m "feat(evolve): parse --recent [N] flag, reject conflicting flags"
```

---

## Task 4: skill 호출시점 본문을 가진 fixture + 해시 추출 검증

**Files:**
- Create: `tests/fixtures/evolve/skill-invocation-session.jsonl`
- Test: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: fixture 생성**

`tests/fixtures/evolve/skill-invocation-session.jsonl` 생성. Skill tool_use + 그에 연결된 `isMeta` 주입 본문 한 쌍. 본문은 짧은 마크다운(frontmatter 없음, "Base directory" 첫 줄 포함):

```jsonl
{"type":"ai-title","aiTitle":"Skill invocation fixture"}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"/me:qa 이거 동작해?"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"확인하겠습니다."},{"type":"tool_use","id":"toolu_qa1","name":"Skill","input":{"skill":"me:qa"}}]}}
{"type":"user","isMeta":true,"sourceToolUseID":"toolu_qa1","message":{"role":"user","content":[{"type":"text","text":"Base directory for this skill: /Users/x/.claude/plugins/cache/bstack/bstack/17.17.0/skills/qa\n\n# qa skill body\n\nThis is the qa skill body line one.\n"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"toolu_qa1","content":"Launching skill: me:qa"}]}}
```

- [ ] **Step 2: 실패하는 테스트 작성 (주입 본문 캡처 → skills[]에 노출)**

`tests/me/evolve-build-index.bats`에 fixture 경로 상수와 테스트 추가. 파일 상단 상수 블록(현재 line 10-14)에 추가:

```bash
SKILL_INVOCATION_FIXTURE="${PROJECT_ROOT}/tests/fixtures/evolve/skill-invocation-session.jsonl"
```

테스트 추가:

```bash
@test "evolve build-index: --recent single fixture surfaces invoked skill in skills[]" {
    # 임시 프로젝트 디렉터리에 fixture를 단일 세션으로 배치하고 cwd 기반 자동탐지로 --recent 실행
    local proj="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$proj"
    cd "$proj"
    local pdir="$HOME/.claude/projects/$(echo "$proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    cp "$SKILL_INVOCATION_FIXTURE" "$pdir/sess1.jsonl"
    run bun "$INDEXER" --recent 5
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.mode == "recent"'
    echo "$output" | jq -e '[.skills[] | select(.name == "qa")] | length == 1'
}
```

> 주: skill 식별자는 Base directory의 마지막 디렉터리명이므로 `"qa"`(접두사 `me:` 없음). SKILL.md 문서화 시 이 점을 반영.

- [ ] **Step 3: 테스트 실패 확인**

Run: `bats tests/me/evolve-build-index.bats -f "surfaces invoked skill"`
Expected: FAIL (`--recent` 진입점/`buildRecentIndex` 미구현 → `.mode`가 없음)

- [ ] **Step 4: (구현은 Task 5에서)** — 이 Task는 fixture와 테스트만 커밋

```bash
git add tests/fixtures/evolve/skill-invocation-session.jsonl tests/me/evolve-build-index.bats
git commit -m "test(evolve): add skill-invocation fixture and --recent skills[] test"
```

---

## Task 5: 세션 선정 + buildRecentIndex + 진입점 분기

**Files:**
- Modify: `plugins/me/skills/evolve/scripts/build-index.ts`
- Test: `tests/me/evolve-build-index.bats` (Task 4 테스트가 여기서 통과)

- [ ] **Step 1: 멀티세션 타입 + 세션 선정 헬퍼 추가**

`SessionIndex` 인터페이스(현재 line 41-47) 아래에 추가:

```typescript
interface RecentSkill {
  name: string;
  skill_path: string;     // 현재 디스크 SKILL.md 경로 (제안 target 후보)
  stale: boolean;         // 세션 이후 본문 변경 여부
  dropped: boolean;       // stale 또는 파일없음 → events 제외됨
  seen_in: string[];      // 등장한 session_id 목록
  events: Event[];        // dropped면 빈 배열
}

interface RecentIndex {
  mode: "recent";
  session_count: number;
  sessions: Array<{ session_id: string; session_title?: string; turns: number }>;
  skills: RecentSkill[];
  summary: { headline: string };
}
```

`resolveTranscriptPath`(현재 line 342-367) 아래에 세션 N개 선정 헬퍼 추가:

```typescript
function recentSessionPaths(cwd: string, n: number): string[] {
  const projectDir = join(homedir(), ".claude", "projects", encodeCwd(cwd));
  if (!existsSync(projectDir)) {
    console.error(`transcript directory not found: ${projectDir}`);
    process.exit(14);
  }
  const files = readdirSync(projectDir)
    .filter((f) => f.endsWith(".jsonl"))
    .map((f) => ({ path: join(projectDir, f), mtime: statSync(join(projectDir, f)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime)
    .slice(0, n);
  if (files.length === 0) {
    console.error(`no .jsonl files in ${projectDir}`);
    process.exit(14);
  }
  return files.map((f) => f.path);
}
```

- [ ] **Step 2: buildRecentIndex 추가**

`buildIndex`(현재 line 325-335) 아래에 추가. skill별로 events를 모으고, 호출시점 본문 해시 vs 현재 디스크 본문 해시로 stale 판정:

```typescript
function currentBodyHash(baseDir: string): string | null {
  const skillMd = join(baseDir, "SKILL.md");
  if (!existsSync(skillMd)) return null;
  return bodyHash(stripFrontmatter(readFileSync(skillMd, "utf8")));
}

function buildRecentIndex(paths: string[]): RecentIndex {
  const sessions: RecentIndex["sessions"] = [];
  // name -> 누적 상태
  const acc = new Map<string, {
    baseDir: string;
    invokedHashes: Set<string>;
    seen: Set<string>;
    events: Event[];
  }>();

  for (const p of paths) {
    const sessionId = basename(p, ".jsonl");
    const { turns, sessionTitle, skillInvocations } = loadTurns(p);
    const events = buildEvents(turns);
    sessions.push({ session_id: sessionId, ...(sessionTitle ? { session_title: sessionTitle } : {}), turns: turns.length });

    // 이 세션에서 호출된 skill 이름 집합 + 호출시점 본문 해시
    const invokedNames = new Set<string>();
    for (const inv of skillInvocations) {
      invokedNames.add(inv.name);
      if (!acc.has(inv.name)) acc.set(inv.name, { baseDir: inv.baseDir, invokedHashes: new Set(), seen: new Set(), events: [] });
      const a = acc.get(inv.name)!;
      a.baseDir = inv.baseDir; // 최신 호출의 baseDir 사용
      a.invokedHashes.add(bodyHash(inv.injectedBody));
      a.seen.add(sessionId);
    }

    // events를 해당 세션에서 호출된 skill로 귀속.
    // events의 session 식별을 위해 t를 "sessionId#turn" 문자열 마킹.
    for (const ev of events) {
      const tagged: Event = { ...ev, session: sessionId } as Event;
      // skill 이벤트는 그 skill에, 그 외 신호는 같은 세션에서 호출된 모든 skill에 귀속
      if (ev.kind === "skill" && ev.name) {
        const short = ev.name.includes(":") ? ev.name.split(":").pop()! : ev.name;
        if (acc.has(short)) acc.get(short)!.events.push(tagged);
      } else {
        for (const name of invokedNames) acc.get(name)!.events.push(tagged);
      }
    }
  }

  const skills: RecentSkill[] = [];
  for (const [name, a] of acc) {
    const nowHash = currentBodyHash(a.baseDir);
    // stale = 현재 본문이 호출시점 본문들 중 어느 것과도 일치하지 않음
    const stale = nowHash === null ? true : !a.invokedHashes.has(nowHash);
    const dropped = stale;
    skills.push({
      name,
      skill_path: join(a.baseDir, "SKILL.md"),
      stale,
      dropped,
      seen_in: [...a.seen],
      events: dropped ? [] : a.events,
    });
  }
  skills.sort((x, y) => y.events.length - x.events.length);

  const droppedN = skills.filter((s) => s.dropped).length;
  return {
    mode: "recent",
    session_count: sessions.length,
    sessions,
    skills,
    summary: { headline: `${sessions.length} sessions · ${skills.length} skills · ${droppedN} dropped` },
  };
}
```

- [ ] **Step 2b: Event 타입에 session 필드 추가**

`Event` 인터페이스(현재 line 13-27)에 optional 필드 추가:

```typescript
interface Event {
  t: number;
  kind: EventKind;
  text?: string;
  prior?: string[];
  name?: string;
  args?: string;
  by?: "user" | "assistant";
  tool?: string;
  desc?: string;
  sub?: string;
  model?: string;
  pattern?: string;
  n?: number;
  session?: string;
}
```

- [ ] **Step 3: 진입점 분기**

진입점(현재 line 385-391)을 교체:

```typescript
const opts = parseArgs(process.argv);
if (opts.recent !== undefined) {
  const paths = recentSessionPaths(process.cwd(), opts.recent);
  console.log(JSON.stringify(buildRecentIndex(paths), null, 2));
} else {
  const transcriptPath = resolveTranscriptPath({
    jsonlPath: opts.jsonlPath,
    sessionId: opts.sessionId,
    cwd: process.cwd(),
  });
  console.log(JSON.stringify(buildIndex(transcriptPath), null, 2));
}
```

- [ ] **Step 4: Task 4 테스트 통과 확인**

Run: `bats tests/me/evolve-build-index.bats -f "surfaces invoked skill"`
Expected: PASS (`.mode == "recent"`, skills[]에 `qa` 1건)

- [ ] **Step 5: Commit**

```bash
git add plugins/me/skills/evolve/scripts/build-index.ts
git commit -m "feat(evolve): build multi-session recent index with stale detection"
```

---

## Task 6: stale 판정 분기 테스트 (내용 동일/변경/파일없음)

전제: "버전은 올랐지만 내용 동일 → stale=false"가 핵심. 디스크에 실제 SKILL.md가 있어야 비교 가능하므로, 임시 디렉터리에 SKILL.md를 만들고 fixture의 Base directory를 그 경로로 맞춘다.

**Files:**
- Test: `tests/me/evolve-build-index.bats`

- [ ] **Step 1: 내용 동일 → stale:false 테스트 작성**

`tests/me/evolve-build-index.bats`에 추가. 임시 skill 디렉터리 + 그 경로를 Base directory로 갖는 동적 fixture를 만든다. 디스크 SKILL.md는 frontmatter를 포함하고, 본문은 주입 본문과 동일:

```bash
@test "evolve build-index: identical body → stale:false (version-agnostic)" {
    local skilldir="$BATS_TEST_TMPDIR/skills/demo"
    mkdir -p "$skilldir"
    # 디스크 SKILL.md: frontmatter 있음, 본문은 주입과 동일
    printf -- '---\nname: demo\ndescription: d\n---\n# demo body\n\nidentical line.\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/proj1"
    mkdir -p "$proj"; cd "$proj"
    local pdir="$HOME/.claude/projects/$(echo "$proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    # 주입 본문 = frontmatter 없는 동일 본문, 첫 줄은 Base directory
    local body="Base directory for this skill: $skilldir\n\n# demo body\n\nidentical line.\n"
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"demo"}}]}}\n' > "$pdir/s.jsonl"
    printf '{"type":"user","isMeta":true,"sourceToolUseID":"t1","message":{"role":"user","content":[{"type":"text","text":"%b"}]}}\n' "$body" >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "demo")][0].stale == false'
}
```

- [ ] **Step 2: 내용 변경 → stale:true 테스트 작성**

```bash
@test "evolve build-index: changed body → stale:true (dropped, no events)" {
    local skilldir="$BATS_TEST_TMPDIR/skills/demo2"
    mkdir -p "$skilldir"
    printf -- '---\nname: demo2\n---\n# demo body\n\nCHANGED ON DISK.\n' > "$skilldir/SKILL.md"

    local proj="$BATS_TEST_TMPDIR/proj2"
    mkdir -p "$proj"; cd "$proj"
    local pdir="$HOME/.claude/projects/$(echo "$proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local body="Base directory for this skill: $skilldir\n\n# demo body\n\nOLD VERSION AT INVOCATION.\n"
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"demo2"}}]}}\n' > "$pdir/s.jsonl"
    printf '{"type":"user","isMeta":true,"sourceToolUseID":"t1","message":{"role":"user","content":[{"type":"text","text":"%b"}]}}\n' "$body" >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].stale == true'
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].dropped == true'
    echo "$output" | jq -e '[.skills[] | select(.name == "demo2")][0].events | length == 0'
}
```

- [ ] **Step 3: 파일 없음 → stale:true 테스트 작성**

```bash
@test "evolve build-index: missing disk SKILL.md → stale:true" {
    local proj="$BATS_TEST_TMPDIR/proj3"
    mkdir -p "$proj"; cd "$proj"
    local pdir="$HOME/.claude/projects/$(echo "$proj" | sed 's/[/.]/-/g')"
    mkdir -p "$pdir"
    local body="Base directory for this skill: $BATS_TEST_TMPDIR/skills/ghost\n\n# ghost body\n"
    printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Skill","input":{"skill":"ghost"}}]}}\n' > "$pdir/s.jsonl"
    printf '{"type":"user","isMeta":true,"sourceToolUseID":"t1","message":{"role":"user","content":[{"type":"text","text":"%b"}]}}\n' "$body" >> "$pdir/s.jsonl"

    run bun "$INDEXER" --recent 3
    rm -rf "$pdir"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '[.skills[] | select(.name == "ghost")][0].stale == true'
}
```

- [ ] **Step 4: 세 테스트 모두 통과 확인**

Run: `bats tests/me/evolve-build-index.bats -f "stale\|version-agnostic\|missing disk"`
Expected: 3 PASS. 특히 "version-agnostic"은 frontmatter 차이만 있고 본문 동일 → stale:false 임을 증명(버전 비의존).

- [ ] **Step 5: Commit**

```bash
git add tests/me/evolve-build-index.bats
git commit -m "test(evolve): cover stale detection (identical/changed/missing body)"
```

---

## Task 7: 단일세션 회귀 + 전체 테스트 통과 확인

**Files:**
- Test: `tests/me/evolve-build-index.bats` (전체)

- [ ] **Step 1: 전체 BATS 통과 확인 (기존 + 신규)**

Run: `bats tests/me/evolve-build-index.bats`
Expected: 모든 테스트 PASS. 기존 단일세션 테스트(turns==9, top-level keys 등)가 깨지지 않음 = 하위 호환 회귀 없음.

- [ ] **Step 2: 단일세션 출력에 mode/skills 필드가 없음을 명시 확인**

Run: `bun plugins/me/skills/evolve/scripts/build-index.ts tests/fixtures/evolve/sample-session.jsonl | jq -e 'has("mode") | not'`
Expected: `true`

---

## Task 8: SKILL.md 문서화 (`--recent` + 멀티세션 스키마 + stale 규칙)

**Files:**
- Modify: `plugins/me/skills/evolve/SKILL.md`

> 메모리(`feedback_avoid_over_testing_skills`): 문서 변경은 과한 테스트 금지. 이 Task는 문서만 — 테스트 없음.

- [ ] **Step 1: CLI 사용법 블록에 --recent 추가**

`SKILL.md`의 사용법 블록(현재 line 20-24)을 교체:

```
/me:evolve                          analyze the current session
/me:evolve --session <id>           analyze a specific session by transcript session id
/me:evolve --recent                 analyze the most recent 10 sessions (multi-session review)
/me:evolve --recent <N>             analyze the most recent N sessions
/me:evolve --dry-run                show proposals only, don't apply
```

- [ ] **Step 2: Phase 0에 --recent 동작과 멀티세션 인덱스 설명 추가**

Phase 0 섹션(현재 line 48-56 부근)의 `build-index.ts` 호출 설명 뒤에 추가:

```markdown
### --recent 모드 (멀티세션 전반 검토)

`--recent [N]` (기본 N=10)이 주어지면 인덱서는 단일 세션 대신 최근 N개 세션을 모아 **멀티세션 인덱스**를 출력한다 (`mode: "recent"`). 출력은 `skills[]` 중심이다:

- 각 skill 항목: `name`, `skill_path`(현재 디스크 SKILL.md), `stale`, `dropped`, `seen_in`(등장 세션), `events`.
- **stale 판정**: 인덱서가 transcript에 보존된 *호출 시점 SKILL.md 본문*의 해시와 *현재 디스크 본문*의 해시를 비교한다. 다르면(또는 디스크에 파일 없음) `stale:true` → `dropped:true` → `events`는 빈 배열. 이미 진화한 skill을 옛 신호로 다시 건드리지 않기 위함이다. **버전 번호가 아니라 본문 내용 해시로 판정**하므로 "버전만 오르고 내용 동일"은 stale이 아니다.
- skill 식별자는 Base directory의 마지막 디렉터리명(예: `qa`)이며, 슬래시커맨드 접두사(`me:`)는 없을 수 있다.

`--recent`와 `--session`은 동시 사용 불가(인덱서가 exit 2). `--dry-run`은 여전히 main agent만 소비하며 인덱서에 전달하지 않는다.
```

- [ ] **Step 3: Phase 1에 멀티세션 처리 지침 추가**

Phase 1 섹션의 프롬프트 구성 항목(현재 line 64-67 부근, "The full index JSON" 항목)에 한 줄 추가:

```markdown
   - **멀티세션(`mode:"recent"`)인 경우**: 인덱스는 `skills[]` 배열이다. 각 skill의 `events[]`를 skill별로 분석하라. `dropped:true`(stale) skill은 인덱서가 이미 events를 비웠으므로 절대 제안 대상이 아니다 — 안전망으로, 혹 `stale:true`가 보이면 그 skill 제안을 만들지 마라. 각 event의 `session` 필드로 어느 세션의 증거인지 식별하고, evidence 인용 시 세션을 함께 표기하라. `skill_path`가 제안 target 후보다.
```

- [ ] **Step 4: 변경 확인 (렌더 정상)**

Run: `head -30 plugins/me/skills/evolve/SKILL.md`
Expected: 사용법 블록에 `--recent` 두 줄이 보임. (frontmatter/구조 깨짐 없음)

- [ ] **Step 5: Commit**

```bash
git add plugins/me/skills/evolve/SKILL.md
git commit -m "docs(evolve): document --recent multi-session review and stale rule"
```

---

## Self-Review 결과

**Spec coverage:** 최근 N개 세션 수집(Task 5), 호출시점 본문 캡처(Task 2), 본문 해시 비교 stale 판정(Task 1·5·6), 버전 비의존(Task 6 version-agnostic 테스트), `--recent [N]` 플래그(Task 3), `--session` 모순 거부(Task 3), 멀티세션 출력 스키마(Task 5), 단일세션 하위호환(Task 7), Phase 1/2 문서(Task 8) — 모두 태스크로 매핑됨. Phase 2(apply loop)는 spec상 "변경 없음"이라 코드 태스크 불필요, 문서 반영만 Task 8에 포함.

**Placeholder scan:** 모든 코드 단계에 실제 코드 블록 포함. "적절한 에러 처리" 류 모호 표현 없음.

**Type consistency:** `SkillInvocation{name,baseDir,injectedBody}`, `RecentSkill{name,skill_path,stale,dropped,seen_in,events}`, `RecentIndex{mode,session_count,sessions,skills,summary}`, `Event.session?` — Task 2/5/5b에서 정의한 이름이 buildRecentIndex 사용처와 일치. 헬퍼명 `stripBaseDirLine`/`stripFrontmatter`/`bodyHash`/`currentBodyHash`/`recentSessionPaths`/`buildRecentIndex` 일관 사용.
