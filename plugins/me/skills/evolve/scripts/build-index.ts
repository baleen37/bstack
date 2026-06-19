#!/usr/bin/env bun
// build-index.ts — transcript jsonl을 SessionIndex JSON으로 변환
// 사용: bun build-index.ts [<jsonl-path-or-worktree-dir>] [--session <id>]
// 출력: stdout에 JSON

import { readFileSync, existsSync, readdirSync, statSync, realpathSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { homedir } from "node:os";

// ── 하네스 트랜스크립트 포맷 의존 상수 ──────────────────
// 이 인덱서는 Claude Code가 기록하는 트랜스크립트 .jsonl 의 내부 라인 포맷에 의존한다.
// 이 포맷은 공개 스키마가 없고 하네스 버전업으로 조용히 바뀔 수 있다. 깨질 때 throw가 아니라
// 빈 결과를 내므로(=신호 없음과 구분 불가) 의존 지점을 여기 한 곳에 모아 추적·점검을 쉽게 한다.
// line/Event/signal 용어 구분은 아래 "타입" 블록 참고. 새 의존이 생기면 반드시 이 블록에 추가할 것.
const FMT = {
  // 슬래시 스킬 호출 시 user 라인에 주입되는 본문의 첫 줄. 스킬 호출 검출의 유일한 앵커.
  skillInjectionMarker: "Base directory for this skill:",
  // 세션 제목 라인: { type: aiTitleType, [aiTitleField]: "..." }
  aiTitleType: "ai-title",
  aiTitleField: "aiTitle",
  // user 라인이 하네스 주입 메타(스킬 본문 등)임을 표시하는 불리언 필드.
  metaFlag: "isMeta",
  // 인터럽트 마커: user 라인의 interruptedMessageId 존재 / assistant message.stop_reason 값.
  userInterruptField: "interruptedMessageId",
  assistantInterruptStopReason: "interrupted",
} as const;

// ── 타입 ───────────────────────────────────────────────
// 용어 정리:
//   line   — 하네스가 jsonl에 기록하는 한 줄(하네스 공식 용어로는 "event"). 이 코드의 입력 단위.
//   Event  — 이 도구가 line들에서 추출한 friction 레코드. 이 코드의 출력 단위(아래 타입).
//   signal — Event들을 kind별로 센 한 줄 요약 문자열(summarizeSignal). Event(단위)와 다른 층위.
type EventKind = "user" | "skill" | "interrupt" | "error" | "agent" | "repeat";

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
  session?: string; // --recent/--skill에서만. 신호의 출처 session_id (cross-session 반복 판정용).
}

interface Summary {
  headline: string;
}

interface SessionIndex {
  session_id: string;
  session_title?: string;
  turns: number;
  summary: Summary;
  events: Event[];
}

interface RecentSkill {
  name: string;
  skill_path: string;     // transcript가 가리킨 호출 시점 base 경로의 SKILL.md (보통 캐시 경로)
  versions: string[];     // 등장한 모든 버전 (정렬, 컨텍스트용). 신호 귀속에는 안 씀.
  seen_in: string[];      // 등장한 session_id 목록 (정렬)
  signal: string;         // kind별 카운트 한 줄 요약 (LLM이 어디부터 볼지 판단용)
  events: Event[];        // 이 skill 이름에 귀속된 모든 Event(전 세션 합산). 각 Event에 출처 session 태그.
}

interface RecentIndex {
  mode: "recent";
  session_count: number;
  sessions: Array<{ session_id: string; session_title?: string; turns: number }>;
  skills: RecentSkill[];
  summary: { headline: string };
}

// ── 입력 파싱 ──────────────────────────────────────────
interface ToolResultPayload {
  content: string;
  isError: boolean;
}

interface Turn {
  index: number;
  type: "user" | "assistant";
  userText?: string;
  toolUses: Array<{ name: string; input: any }>;
  toolResults: ToolResultPayload[];
  interrupted: boolean;
  interruptedBy?: "user" | "assistant";
}

interface SkillInvocation {
  name: string;          // skill 식별자 (Base directory의 마지막 디렉터리명)
  baseDir: string;       // 주입 본문의 Base directory 절대경로
  version: string;
  turn: number;          // 주입 시점까지 누적된 turn 수 (= 직전 호출 turn). 이후 신호의 소유 스킬 결정용.
}

interface LoadedTranscript {
  turns: Turn[];
  sessionTitle?: string;
  skillInvocations: SkillInvocation[];
}

interface SignalSummary {
  signal: string;
  weight: number;
}

// qualified skill 이름(`me:research`)에서 basename(`research`)을 뽑는다. 콜론이 없으면 그대로.
function skillBaseName(name: string): string {
  return name.includes(":") ? name.split(":").pop()! : name;
}

function getOrCreate<K, V>(map: Map<K, V>, key: K, init: () => V): V {
  const existing = map.get(key);
  if (existing !== undefined) return existing;
  const value = init();
  map.set(key, value);
  return value;
}

function normalizeToolResultContent(raw: any): string {
  if (typeof raw === "string") return raw;
  if (Array.isArray(raw)) {
    return raw.map((c) => (typeof c === "string" ? c : c?.text ?? JSON.stringify(c))).join("\n");
  }
  return JSON.stringify(raw ?? "");
}

function loadTurns(jsonlPath: string): LoadedTranscript {
  const lines = readFileSync(jsonlPath, "utf8").split("\n").filter(Boolean);
  const turns: Turn[] = [];
  const skillInvocations: SkillInvocation[] = [];
  let sessionTitle: string | undefined;
  for (const line of lines) {
    const obj = JSON.parse(line);
    if (obj.type === FMT.aiTitleType && typeof obj[FMT.aiTitleField] === "string") {
      sessionTitle = obj[FMT.aiTitleField];
      continue;
    }
    // skill 호출시점 주입 본문 (isMeta user/text, 첫 줄 "Base directory for this skill:")
    if (obj.type === "user" && obj[FMT.metaFlag] === true) {
      const c = obj.message?.content;
      const text = Array.isArray(c) && c[0]?.type === "text" ? c[0].text : undefined;
      if (typeof text === "string") {
        const m = text.match(new RegExp(`^${escapeRegExp(FMT.skillInjectionMarker)}\\s*(.+?)\\s*(?:${LINE_BREAK}|$)`));
        if (m) {
          const baseDir = m[1];
          skillInvocations.push({
            name: basename(baseDir),
            baseDir,
            version: skillVersion(baseDir),
            turn: turns.length, // 주입은 turn으로 안 세므로 직전까지의 turn 수가 이 호출의 활성 시작점
          });
        }
      }
      continue; // 주입 메시지는 turn으로 세지 않음
    }
    if (obj.type !== "user" && obj.type !== "assistant") continue;
    const userInterruptedMarker = obj[FMT.userInterruptField] !== undefined;
    const assistantInterruptedMarker = obj.message?.stop_reason === FMT.assistantInterruptStopReason;
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

// 하네스 포맷이 바뀌면 파싱은 throw 없이 빈 결과를 내고, evolve는 그걸 "신호 없음"으로 오인한다.
// 실제 세션이라면 거의 항상 성립하는 불변식이 깨졌을 때 stderr로 경고해 둘을 구분한다.
// 경고는 진단용일 뿐 결과를 바꾸지 않는다(과잉 필터 금지: 실제로 비어있을 수도 있으므로 막지 않는다).
const HEALTHCHECK_MIN_TURNS = 10;
function warnIfFormatLooksBroken(jsonlPath: string, loaded: LoadedTranscript): void {
  const { turns, skillInvocations } = loaded;
  if (turns.length === 0) {
    console.error(`[evolve] warning: ${basename(jsonlPath)} parsed to 0 turns — transcript line format may have changed`);
    return;
  }
  if (turns.length < HEALTHCHECK_MIN_TURNS) return; // 짧은 세션은 도구·스킬이 없어도 정상
  const sawToolUse = turns.some((t) => t.toolUses.length > 0);
  if (!sawToolUse && skillInvocations.length === 0) {
    console.error(
      `[evolve] warning: ${basename(jsonlPath)} has ${turns.length} turns but 0 tool_use and 0 skill injections — ` +
        `extraction may be silently failing (check FMT.* against the current harness transcript format)`,
    );
  }
}

// 정규식에 리터럴을 안전하게 끼워넣기 위한 메타문자 이스케이프.
function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// 스킬 호출 본문 주입의 줄바꿈 변종(LF/CRLF/CR)을 매칭하기 위한 패턴. loadTurns의 Base directory 추출에 사용.
const LINE_BREAK = "(?:\\r\\n|\\n|\\r)";

function skillVersion(baseDir: string): string {
  const parts = baseDir.split(/[\\/]/);
  const i = parts.lastIndexOf("skills");
  const candidate = i > 0 ? parts[i - 1] : undefined;
  return candidate && /^\d+\.\d+\.\d+(?:[-+].*)?$/.test(candidate) ? candidate : "unknown";
}

// ── tool_use 요약 (user.prior에 사용) ──
function summarizeToolUse(tu: { name: string; input: any }): string {
  const name = tu.name;
  let arg = "";
  if (name === "Bash") arg = (tu.input?.command ?? "").slice(0, 60);
  else if (name === "Read" || name === "Edit" || name === "Write") arg = tu.input?.file_path ?? "";
  else if (name === "Grep" || name === "Glob") arg = tu.input?.pattern ?? "";
  else if (name === "Agent") arg = tu.input?.description ?? "";
  else if (name === "Skill") arg = tu.input?.skill ?? "";
  // 그 외 도구(MCP, PushNotification, Monitor 등)는 raw JSON을 덤프하지 않는다 — 도구 이름만.
  return arg ? `${name}: ${arg}` : name;
}

const BOOKKEEPING_TOOLS = new Set(["TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "AskUserQuestion"]);

// 거의 모든 Bash 호출에 붙는 셸 보일러플레이트. 이걸 repeat 키로 쓰면 "cd <worktree>"
// 같은 비신호가 최상위 repeat을 차지한다. 키 산출 시 이런 세그먼트는 건너뛴다.
const REPEAT_NOISE_PREFIXES = new Set(["cd", "echo", "ls", "pwd", "cat", "export", "true", "set"]);

// repeat 집계용 Bash 키. &&/;/| 로 분리해 보일러플레이트 세그먼트를 버리고 첫 의미있는 명령의
// 앞 2토큰을 키로 쓴다. 의미있는 세그먼트가 없으면 빈 문자열(=repeat 후보 제외).
function repeatBashKey(cmd: string): string {
  for (const segment of cmd.split(/&&|\|\||;|\|/)) {
    const tokens = segment.trim().split(/\s+/).filter(Boolean);
    if (tokens.length === 0) continue;
    if (REPEAT_NOISE_PREFIXES.has(tokens[0])) continue;
    return tokens.slice(0, 2).join(" ");
  }
  return "";
}

function priorAssistantActions(turns: Turn[], currentIdx: number): string[] {
  const actions: string[] = [];
  for (let i = currentIdx - 1; i >= 0 && actions.length < 3; i--) {
    const t = turns[i];
    if (t.type !== "assistant") continue;
    for (const tu of t.toolUses) {
      if (BOOKKEEPING_TOOLS.has(tu.name)) continue;
      actions.push(summarizeToolUse(tu));
      if (actions.length >= 3) break;
    }
    if (actions.length > 0) break;
  }
  return actions;
}

// ── 슬래시 커맨드 검출 ──────────────────────────────────
const SLASH_CMD_TAG = /<command-name>\/([a-z0-9:_-]+)<\/command-name>/i;
const SLASH_CMD_PREFIX = /^\/([a-z0-9:_-]+)\b(.*)$/i;
const SLASH_CMD_ARGS_TAG = /<command-args>([\s\S]*?)<\/command-args>/i;

interface DetectedSlash {
  name: string;
  args?: string;
}

function detectSlashCommand(userText: string): DetectedSlash | undefined {
  const tag = userText.match(SLASH_CMD_TAG);
  if (tag) {
    const argsTag = userText.match(SLASH_CMD_ARGS_TAG);
    const args = argsTag?.[1]?.trim();
    return args ? { name: tag[1], args: args.slice(0, 200) } : { name: tag[1] };
  }
  const prefix = userText.trim().match(SLASH_CMD_PREFIX);
  if (!prefix) return undefined;
  const rest = prefix[2] ?? "";
  // 슬래시 커맨드 이름에는 경로 구분자가 없다. 이름 바로 뒤에 "/"가 오면 이건
  // 슬래시 커맨드가 아니라 절대경로("/Users/…")로 시작하는 사용자 발화다. skill로 오분류하지 않는다.
  if (rest.startsWith("/")) return undefined;
  const args = rest.trim();
  return args ? { name: prefix[1], args: args.slice(0, 200) } : { name: prefix[1] };
}

const PSEUDO_USER_PREFIXES = [
  FMT.skillInjectionMarker,
  "<bash-input>",
  "<bash-stdout>",
  "<bash-stderr>",
  "<local-command-",
  "[Request interrupted",
  "<task-notification>", // 하네스 주입 Monitor/Task 완료 알림 — user 발화 아님
  "<system-reminder>", // 하네스 주입 context — user 발화 아님
  "<ide-context>", // 하네스 주입 IDE context — user 발화 아님
];

function isPseudoUser(userText: string): boolean {
  const trimmed = userText.trimStart();
  return PSEUDO_USER_PREFIXES.some((p) => trimmed.startsWith(p));
}

// ── events 빌드 ────────────────────────────────────────
function buildEvents(turns: Turn[], skillInvocations: SkillInvocation[] = []): Event[] {
  const events: Event[] = [];
  const interruptClaimed = new Set<number>();

  // user / skill / interrupt(user) / error / agent 를 순회 중에 emit
  for (let i = 0; i < turns.length; i++) {
    const t = turns[i];

    if (t.type === "user") {
      // skill 호출은 user 발화에 자동 주입된 태그. 그건 skill event로만 emit (user event 중복 X).
      // 단 사용자가 직접 친 슬래시 커맨드 (prefix form)는 user event도 함께 의미 있을 수 있지만
      // 분류 노이즈를 줄이기 위해 skill만 emit.
      if (t.userText) {
        const slash = detectSlashCommand(t.userText);
        if (slash) {
          const ev: Event = { t: t.index, kind: "skill", name: slash.name };
          if (slash.args) ev.args = slash.args;
          events.push(ev);
        } else if (!isPseudoUser(t.userText)) {
          events.push({
            t: t.index,
            kind: "user",
            text: t.userText.trim().slice(0, 200),
            prior: priorAssistantActions(turns, i),
          });
        }
      }
      // user turn의 interrupt 마커
      if (t.interrupted && !interruptClaimed.has(t.index)) {
        events.push({ t: t.index, kind: "interrupt", by: t.interruptedBy ?? "user" });
        interruptClaimed.add(t.index);
      }
      // tool_result 안의 error
      for (const tr of t.toolResults) {
        if (!tr.isError) continue;
        const prevAssist = [...turns.slice(0, i)].reverse().find((a) => a.type === "assistant" && a.toolUses.length > 0);
        const toolName = prevAssist?.toolUses[prevAssist.toolUses.length - 1]?.name ?? "unknown";
        // tool 이름만으로는 "어떤 인자로 호출하다 났는지"를 알 수 없어 소유권 판정이 막힌다.
        // user처럼 직전 행동을 prior로 담아(예: "Edit: /path") 어느 파일/명령이 에러를 냈는지 보이게 한다.
        events.push({
          t: t.index,
          kind: "error",
          tool: toolName,
          text: tr.content.slice(0, 200),
          prior: priorAssistantActions(turns, i),
        });
      }
    } else {
      // assistant
      if (t.interrupted && !interruptClaimed.has(t.index)) {
        events.push({ t: t.index, kind: "interrupt", by: t.interruptedBy ?? "assistant" });
        interruptClaimed.add(t.index);
      }
      for (const tu of t.toolUses) {
        if (tu.name === "Agent") {
          const ev: Event = { t: t.index, kind: "agent", desc: String(tu.input?.description ?? "").slice(0, 200) };
          if (tu.input?.subagent_type) ev.sub = tu.input.subagent_type;
          if (tu.input?.model) ev.model = tu.input.model;
          events.push(ev);
        }
      }
    }
  }

  // repeat 패턴: 같은 Bash prefix / Read path 3회 이상 → 마지막 등장 turn에 1 event
  const bashOccur = new Map<string, number[]>();
  const readOccur = new Map<string, number[]>();
  for (const t of turns) {
    for (const tu of t.toolUses) {
      if (tu.name === "Bash") {
        const prefix = repeatBashKey(tu.input?.command ?? "");
        if (!prefix) continue;
        getOrCreate(bashOccur, prefix, () => []).push(t.index);
      } else if (tu.name === "Read") {
        const p: string = tu.input?.file_path ?? "";
        if (!p) continue;
        getOrCreate(readOccur, p, () => []).push(t.index);
      }
    }
  }
  const repeats: Event[] = [];
  for (const [prefix, list] of bashOccur) {
    if (list.length < 3) continue;
    repeats.push({ t: list[list.length - 1], kind: "repeat", pattern: prefix, n: list.length });
  }
  for (const [path, list] of readOccur) {
    if (list.length < 3) continue;
    repeats.push({ t: list[list.length - 1], kind: "repeat", pattern: path, n: list.length });
  }
  // Skill 도구로 호출된 스킬은 슬래시 텍스트 없이 isMeta 본문 주입으로만 들어와 위 루프가 못 잡는다.
  // 주입(skillInvocations)을 skill 이벤트로 추가하되, 슬래시로 이미 잡은 같은 호출과는 중복 제거한다.
  // 같은 호출이면 슬래시 이벤트와 주입 turn이 인접(±1)하고 이름이 대응한다(슬래시는 qualified
  // `me:foo`, 주입 name은 basename `foo`일 수 있어 양쪽을 basename으로 맞춰 비교한다).
  const slashSkills = events.filter((e) => e.kind === "skill");
  const injectionSkills: Event[] = [];
  for (const inv of skillInvocations) {
    const dup = slashSkills.some(
      (e) => Math.abs(e.t - inv.turn) <= 1 && e.name !== undefined && skillBaseName(e.name) === skillBaseName(inv.name),
    );
    if (dup) continue;
    injectionSkills.push({ t: inv.turn, kind: "skill", name: inv.name });
  }
  // 정렬: 모든 events를 turn 기준 안정 정렬 (같은 turn 안에서는 emit 순서 유지)
  const combined = [...events, ...repeats, ...injectionSkills];
  combined.sort((a, b) => a.t - b.t);
  return combined;
}

// ── summary: 얕은 탐색용 ───────────────────────────────
// single-session headline. SKILL.md는 이걸 freshness check로만 쓴다(턴 수 + 개선 신호 카운트).
function buildSummary(turns: number, events: Event[]): Summary {
  const counts: Record<string, number> = {};
  for (const e of events) counts[e.kind] = (counts[e.kind] ?? 0) + 1;
  const parts: string[] = [`${turns} turns`];
  for (const kind of ["user", "interrupt", "error", "repeat"] as const) {
    if (counts[kind]) parts.push(`${counts[kind]} ${kind}${counts[kind] > 1 ? "s" : ""}`);
  }
  return { headline: parts.join(" · ") };
}

// kind별 카운트 → 한 줄 요약. interrupt/error/repeat은 개선 신호가 농축된 종류라 앞세운다.
function summarizeSignal(events: Event[]): SignalSummary {
  const counts: Record<string, number> = {};
  for (const event of events) counts[event.kind] = (counts[event.kind] ?? 0) + 1;

  const order: EventKind[] = ["interrupt", "error", "repeat", "user", "agent", "skill"];
  const parts = order.filter((kind) => counts[kind]).map((kind) => `${counts[kind]} ${kind}`);
  return {
    signal: parts.length ? parts.join(", ") : "no events",
    weight: (counts["interrupt"] ?? 0) + (counts["error"] ?? 0) + (counts["repeat"] ?? 0),
  };
}

function buildIndex(jsonlPath: string): SessionIndex {
  const loaded = loadTurns(jsonlPath);
  warnIfFormatLooksBroken(jsonlPath, loaded);
  const { turns, sessionTitle, skillInvocations } = loaded;
  const events = buildEvents(turns, skillInvocations);
  return {
    session_id: basename(jsonlPath, ".jsonl"),
    ...(sessionTitle ? { session_title: sessionTitle } : {}),
    turns: turns.length,
    summary: buildSummary(turns.length, events),
    events,
  };
}

function jsonlFilesInDir(dir: string): Array<{ path: string; mtime: number }> {
  try {
    return readdirSync(dir)
      .filter((f) => f.endsWith(".jsonl"))
      .map((f) => {
        const path = join(dir, f);
        return { path, mtime: statSync(path).mtimeMs };
      });
  } catch {
    return [];
  }
}

// transcript 파일을 최신순(mtime 내림차순)으로 정렬하는 비교자.
const byNewest = (a: { mtime: number }, b: { mtime: number }): number => b.mtime - a.mtime;

function formatRecentHeadline(sessionCount: number, skills: RecentSkill[]): string {
  return `${sessionCount} sessions · ${skills.length} skills`;
}

// 한 skill 이름에 대한 multi-session 누적 상태. body-hash 폐기 후로는 버전 무관하게 평면 합산한다.
interface SkillAccumulator {
  baseDir: string;       // 입력에서 처음 본 호출 경로 (cache SKILL.md 경로 노출용)
  versions: Set<string>; // 등장한 모든 버전 (컨텍스트용)
  seen: Set<string>;     // 이 skill이 등장한 모든 session_id
  events: Event[];       // 이 skill에 귀속된 모든 Event (전 세션 합산)
}

function newAccumulator(baseDir: string): SkillAccumulator {
  return { baseDir, versions: new Set(), seen: new Set(), events: [] };
}

function buildRecentIndex(paths: string[]): RecentIndex {
  const sessions: RecentIndex["sessions"] = [];
  const acc = new Map<string, SkillAccumulator>();

  for (const p of paths) {
    const sessionId = basename(p, ".jsonl");
    const loaded = loadTurns(p);
    warnIfFormatLooksBroken(p, loaded);
    const { turns, sessionTitle, skillInvocations } = loaded;
    const events = buildEvents(turns, skillInvocations);
    sessions.push({ session_id: sessionId, ...(sessionTitle ? { session_title: sessionTitle } : {}), turns: turns.length });

    // 이 세션에서 호출된 skill 이름들을 누적기에 등록 (버전·세션 합산)
    const invokedNames = new Set<string>();
    for (const inv of skillInvocations) {
      invokedNames.add(inv.name);
      const a = getOrCreate(acc, inv.name, () => newAccumulator(inv.baseDir));
      a.seen.add(sessionId);
      a.versions.add(inv.version);
    }

    // events를 해당 세션에서 호출된 skill에 귀속. events에 출처 session 태그.
    // 비-skill 신호(error/interrupt/repeat/user/agent)는 시간상 그 직전에 호출된 스킬에만 귀속한다.
    // 이렇게 해야 한 세션에서 여러 스킬이 호출됐을 때 같은 error가 모든 스킬에 복사되어
    // per-skill signal·정렬 가중치를 오염시키는 일을 막는다. 첫 스킬 호출 이전 신호는 어디에도 안 붙는다.
    // 활성 스킬은 호출 turn(invocation.turn) 시퀀스로 결정한다 — 슬래시 텍스트 유무와 무관.
    // skillInvocations와 events는 둘 다 turn 오름차순이므로 포인터 하나로 함께 훑는다.
    let invIdx = 0;
    let activeName: string | undefined;
    for (const ev of events) {
      while (invIdx < skillInvocations.length && skillInvocations[invIdx].turn <= ev.t) {
        activeName = skillInvocations[invIdx].name;
        invIdx++;
      }
      const tagged: Event = { ...ev, session: sessionId };
      if (ev.kind === "skill" && ev.name) {
        const fallback = skillBaseName(ev.name);
        const target = invokedNames.has(ev.name) ? ev.name : invokedNames.has(fallback) ? fallback : undefined;
        if (target === undefined) continue;
        acc.get(target)!.events.push(tagged);
      } else {
        const owner = activeName;
        if (owner === undefined) continue;
        acc.get(owner)!.events.push(tagged);
      }
    }
  }

  // skill + 정렬 키(weight)를 함께 모은다. 정렬 키는 출력 타입(RecentSkill)을 오염시키지 않게 분리한다.
  const ranked: Array<{ skill: RecentSkill; weight: number }> = [];
  for (const [name, a] of acc) {
    const { signal, weight } = summarizeSignal(a.events);
    ranked.push({
      skill: {
        name,
        skill_path: join(a.baseDir, "SKILL.md"),
        versions: [...a.versions].sort(),
        seen_in: [...a.seen].sort(),
        signal,
        events: a.events,
      },
      weight,
    });
  }
  // 개선 신호(interrupt+error+repeat) 많은 순 → 동률이면 전체 event 수 순 → 이름순.
  ranked.sort(
    (x, y) => y.weight - x.weight || y.skill.events.length - x.skill.events.length || x.skill.name.localeCompare(y.skill.name),
  );
  const skills = ranked.map((r) => r.skill);

  return {
    mode: "recent",
    session_count: sessions.length,
    sessions,
    skills,
    summary: { headline: formatRecentHeadline(sessions.length, skills) },
  };
}

// ── Phase 0: transcript 자동 탐지 ──────────────────────
// 트랜스크립트 저장소 루트. 기본은 ~/.claude/projects. 테스트는 라이브 세션과 섞이지 않도록
// EVOLVE_PROJECTS_DIR 로 격리된 디렉터리를 주입한다(이 override가 없으면 --skill/--recent 스캔이
// 실행 중인 현재 세션까지 끌어와 결과가 비결정적이 된다).
function projectsRoot(): string {
  return process.env.EVOLVE_PROJECTS_DIR || join(homedir(), ".claude", "projects");
}

function encodeCwd(cwd: string): string {
  return cwd.replace(/[/.]/g, "-");
}

// cwd 인코딩에서 worktree base prefix 추출 (worktree들은 `<base>--worktrees-…` 형태)
function projectBasePrefix(cwd: string): string {
  const enc = encodeCwd(cwd);
  const i = enc.indexOf("--worktrees-");
  return i === -1 ? enc : enc.slice(0, i);
}

function recentSessionPaths(cwd: string, n: number): string[] {
  const root = projectsRoot();
  if (!existsSync(root)) {
    console.error(`transcript directory not found: ${root}`);
    process.exit(14);
  }
  // 같은 프로젝트의 모든 worktree 디렉터리를 합친다: base 자체 + base--worktrees-* 형제들.
  // bstack처럼 worktree마다 transcript가 쪼개지는 경우 "최근 N개 세션"이 전체에서 모이게.
  const base = projectBasePrefix(cwd);
  const dirs = readdirSync(root).filter((d) => d === base || d.startsWith(base + "--worktrees-"));
  const files = dirs
    .flatMap((d) => jsonlFilesInDir(join(root, d)))
    .sort(byNewest)
    .slice(0, n);
  if (files.length === 0) {
    console.error(`no .jsonl files for project ${base} (and its worktrees) under ${root}`);
    process.exit(14);
  }
  return files.map((f) => f.path);
}

function transcriptProjectDir(cwd: string): string {
  return join(projectsRoot(), encodeCwd(cwd));
}

function latestTranscriptPathForCwd(cwd: string): string {
  const projectDir = transcriptProjectDir(cwd);
  if (!existsSync(projectDir)) {
    console.error(`transcript directory not found: ${projectDir}`);
    process.exit(14);
  }
  const files = jsonlFilesInDir(projectDir).sort(byNewest);
  if (files.length === 0) {
    console.error(`no .jsonl files in ${projectDir}`);
    process.exit(14);
  }
  return files[0].path;
}

// 주어진 transcript에서 `<name>` skill이 호출된 적 있는지 loadTurns 와 동일한 기준으로 판정.
// 주입 메시지는 "Base directory for this skill: …/skills/<name>" (디렉터리명 = basename) 형태이며,
// loadTurns 의 baseDir 정규식과 같은 경계(줄 끝 또는 다음 토큰)로 매칭해야 단순 경로 언급을 거른다.
// jsonl 안에서 줄바꿈은 "\n" 으로 escape 되어 있으므로 경계는 슬래시/escape 개행/문자열 종료다.
function transcriptInvokesSkill(jsonlPath: string, name: string): boolean {
  let text: string;
  try {
    text = readFileSync(jsonlPath, "utf8");
  } catch {
    return false;
  }
  const esc = escapeRegExp(name);
  // baseDir 마지막 세그먼트가 정확히 <name> 이어야 한다: …/skills/<name> 뒤에 / 또는 escape개행(\n) 또는 따옴표.
  const re = new RegExp(`${escapeRegExp(FMT.skillInjectionMarker)}[^\\n"]*?/${esc}(?:/|\\\\n|")`);
  return re.test(text);
}

function skillNameCandidates(name: string): string[] {
  return [...new Set([name, skillBaseName(name)])];
}

function findSkillSessionPaths(names: string[], n: number): string[] {
  const root = projectsRoot();
  if (!existsSync(root)) {
    console.error(`transcript directory not found: ${root}`);
    process.exit(14);
  }
  return readdirSync(root)
    .flatMap((d) => {
      const full = join(root, d);
      try {
        if (!statSync(full).isDirectory()) return [];
        return jsonlFilesInDir(full).map((f) => f.path);
      } catch {
        return [];
      }
    })
    .filter((p) => names.some((name) => transcriptInvokesSkill(p, name)))
    .map((p) => ({ path: p, mtime: statSync(p).mtimeMs }))
    .sort(byNewest)
    .slice(0, n)
    .map((f) => f.path);
}

function noSkillSessions(name: string): never {
  console.error(`no sessions invoking skill '${name}' found under ${projectsRoot()}`);
  process.exit(14);
}

// ~/.claude/projects 전체에서 `<name>` skill이 호출된 세션을 mtime 순 최근 N개 수집.
// Exact skill names win. If there is no exact match for a qualified name like `me:research`,
// fall back to its basename (`research`) without scanning exact sessions twice.
function resolveSkillSessionPaths(name: string, n: number): { paths: string[]; skillNames: string[] } {
  const exactPaths = findSkillSessionPaths([name], n);
  if (exactPaths.length > 0) return { paths: exactPaths, skillNames: [name] };

  const fallbackNames = skillNameCandidates(name).filter((candidate) => candidate !== name);
  if (fallbackNames.length === 0) noSkillSessions(name);

  const paths = findSkillSessionPaths(fallbackNames, n);
  if (paths.length === 0) noSkillSessions(name);
  return { paths, skillNames: fallbackNames };
}

function expandHomePath(path: string): string {
  return path === "~" || path.startsWith("~/") ? join(homedir(), path.slice(2)) : path;
}

function resolveCwdPath(path: string): string {
  const resolved = resolve(expandHomePath(path));
  if (!existsSync(resolved)) {
    console.error(`cwd path not found: ${resolved}`);
    process.exit(14);
  }
  const real = realpathSync(resolved);
  if (!statSync(real).isDirectory()) {
    console.error(`--cwd expects a directory: ${real}`);
    process.exit(2);
  }
  return real;
}

function resolveTranscriptPath(opts: { jsonlPath?: string; sessionId?: string; cwd: string }): string {
  if (opts.jsonlPath) {
    const path = resolve(expandHomePath(opts.jsonlPath));
    if (!existsSync(path)) {
      console.error(`transcript file not found: ${path}`);
      process.exit(14);
    }
    const resolved = realpathSync(path);
    const stat = statSync(resolved);
    if (stat.isDirectory()) return latestTranscriptPathForCwd(resolved);
    if (!stat.isFile()) {
      console.error(`transcript path is not a file: ${resolved}`);
      process.exit(14);
    }
    return resolved;
  }
  const projectDir = transcriptProjectDir(opts.cwd);
  if (!existsSync(projectDir)) {
    console.error(`transcript directory not found: ${projectDir}`);
    process.exit(14);
  }
  if (opts.sessionId) {
    const candidate = join(projectDir, `${opts.sessionId}.jsonl`);
    if (!existsSync(candidate)) {
      console.error(`session not found: ${candidate}`);
      process.exit(14);
    }
    return candidate;
  }
  return latestTranscriptPathForCwd(opts.cwd);
}

// ── 진입점 ─────────────────────────────────────────────
function printUsage(): void {
  console.log(`Usage: bun build-index.ts [<jsonl-path-or-worktree-dir>] [--cwd <dir>] [--session <id> | --recent [N] | --skill <name> [--recent N]]

Options:
  --cwd <dir>          Resolve current/recent transcripts and repo-owned skills from another cwd.
  --session <id>       Read a transcript id from the current cwd project.
  --recent [N]         Aggregate recent sessions; defaults to 10.
  --skill <name>       Aggregate recent sessions that invoked one skill.
  --help, -h           Show this help.

Notes:
  --dry-run is handled by the /me:evolve skill, not this indexer.
  Plain multi-skill shorthand must be expanded by the caller into separate --skill runs.`);
}

function parseArgs(argv: string[]): { jsonlPath?: string; sessionId?: string; recent?: number; skill?: string; cwd?: string } {
  const args = argv.slice(2);
  let jsonlPath: string | undefined;
  let sessionId: string | undefined;
  let recent: number | undefined;
  let skill: string | undefined;
  let cwd: string | undefined;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--help" || args[i] === "-h") {
      printUsage();
      process.exit(0);
    } else if (args[i] === "--cwd") {
      if (cwd !== undefined) {
        console.error("--cwd can only be specified once");
        process.exit(2);
      }
      const next = args[++i];
      if (next === undefined || next.startsWith("--")) {
        console.error("--cwd requires a directory");
        process.exit(2);
      }
      cwd = resolveCwdPath(next);
    } else if (args[i] === "--session") {
      if (sessionId !== undefined) {
        console.error("--session can only be specified once");
        process.exit(2);
      }
      const next = args[++i];
      if (next === undefined || next.startsWith("--")) {
        console.error("--session requires a session id");
        process.exit(2);
      }
      if (next.endsWith(".jsonl") || next.includes("/") || next.includes("\\")) {
        console.error("--session expects a transcript session id without .jsonl or path separators");
        process.exit(2);
      }
      sessionId = next;
    } else if (args[i] === "--skill") {
      if (skill !== undefined) {
        console.error("--skill can only be specified once");
        process.exit(2);
      }
      const next = args[++i];
      if (next === undefined || next.startsWith("--")) {
        console.error("--skill requires a skill name");
        process.exit(2);
      }
      if (next.includes("/") || next.includes("\\")) {
        console.error("--skill expects a skill name, not a path");
        process.exit(2);
      }
      skill = next;
    } else if (args[i] === "--recent") {
      if (recent !== undefined) {
        console.error("--recent can only be specified once");
        process.exit(2);
      }
      // 다음 토큰이 양의 정수면 N, flag/없음이면 기본 10. 그 외 토큰은 잘못된 N이다.
      const next = args[i + 1];
      if (next !== undefined && /^[1-9][0-9]*$/.test(next)) {
        recent = parseInt(next, 10);
        i++;
      } else if (next !== undefined && (next.endsWith(".jsonl") || next.includes("/") || next.includes("\\"))) {
        console.error("--recent cannot be combined with a transcript path");
        process.exit(2);
      } else if (next !== undefined && !next.startsWith("--")) {
        console.error("--recent requires a positive integer");
        process.exit(2);
      } else {
        recent = 10;
      }
    } else if (args[i].startsWith("--")) {
      console.error(`unknown flag: ${args[i]}`);
      process.exit(2);
    } else if (!jsonlPath) jsonlPath = args[i];
    else {
      console.error(`unexpected argument: ${args[i]}`);
      process.exit(2);
    }
  }
  if (sessionId !== undefined && jsonlPath !== undefined) {
    console.error("--session cannot be combined with a transcript path");
    process.exit(2);
  }
  if (cwd !== undefined && jsonlPath !== undefined) {
    console.error("--cwd cannot be combined with a transcript path");
    process.exit(2);
  }
  if (skill !== undefined && jsonlPath !== undefined) {
    console.error("do not combine --skill with positional arguments; expand plain multi-skill shorthand into separate --skill runs");
    process.exit(2);
  }
  if (skill !== undefined && sessionId !== undefined) {
    console.error("--skill cannot be combined with --session or a transcript path");
    process.exit(2);
  }
  if (recent !== undefined && (sessionId !== undefined || jsonlPath !== undefined)) {
    console.error("--recent cannot be combined with --session or a transcript path");
    process.exit(2);
  }
  if (skill !== undefined && skill.trim() === "") {
    console.error("--skill requires a skill name");
    process.exit(2);
  }
  return { jsonlPath, sessionId, recent, skill, cwd };
}

const opts = parseArgs(process.argv);
const targetCwd = opts.cwd ?? process.cwd();
if (opts.skill !== undefined) {
  const n = opts.recent ?? 10;
  const { paths, skillNames } = resolveSkillSessionPaths(opts.skill, n);
  const index = buildRecentIndex(paths);
  // --skill 은 대상 스킬 하나로 좁혀서 내보낸다 (같은 세션의 다른 스킬은 제외).
  index.skills = index.skills.filter((s) => skillNames.includes(s.name));
  index.summary.headline = formatRecentHeadline(index.session_count, index.skills);
  console.log(JSON.stringify(index, null, 2));
} else if (opts.recent !== undefined) {
  const paths = recentSessionPaths(targetCwd, opts.recent);
  console.log(JSON.stringify(buildRecentIndex(paths), null, 2));
} else {
  const transcriptPath = resolveTranscriptPath({
    jsonlPath: opts.jsonlPath,
    sessionId: opts.sessionId,
    cwd: targetCwd,
  });
  console.log(JSON.stringify(buildIndex(transcriptPath), null, 2));
}
