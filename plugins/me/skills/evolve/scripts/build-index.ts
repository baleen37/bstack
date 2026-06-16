#!/usr/bin/env bun
// build-index.ts — transcript jsonl을 SessionIndex JSON으로 변환
// 사용: bun build-index.ts [<jsonl-path-or-worktree-dir>] [--session <id>]
// 출력: stdout에 JSON

import { readFileSync, existsSync, readdirSync, statSync, realpathSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { homedir } from "node:os";
import { createHash } from "node:crypto";

// ── 타입 ───────────────────────────────────────────────
type EventKind = "user" | "skill" | "interrupt" | "error" | "agent" | "repeat";
type DropReason = "stale" | "missing_current_body";

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

interface Cluster {
  kind: EventKind;
  t_range: [number, number];
  n: number;
  example_t: number;
}

interface Summary {
  headline: string;
  clusters: Cluster[];
}

interface SessionIndex {
  session_id: string;
  session_title?: string;
  turns: number;
  summary: Summary;
  events: Event[];
}

interface ObservedBody {
  hash: string;
  current: boolean;
  versions: string[];
  seen_in: string[];
  signal: string;
}

interface RecentSkill {
  name: string;
  skill_path: string;     // transcript가 가리킨 호출 시점 base 경로의 SKILL.md (보통 캐시 경로)
  repo_path?: string;     // cwd repo 안에서 찾은 편집 가능한 SKILL.md (있으면 직접 edit 대상)
  current_hash?: string;
  drop_reason?: DropReason;
  observed_bodies: ObservedBody[];
  stale: boolean;         // current body가 관측된 본문과 매칭되지 않음
  dropped: boolean;       // drop_reason이 있으면 events 제외됨
  seen_in: string[];      // 등장한 session_id 목록
  signal: string;         // kind별 카운트 한 줄 요약 (LLM이 어디부터 볼지 판단용)
  events: Event[];        // dropped면 빈 배열
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
  hash: string;
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
    if (obj.type === "ai-title" && typeof obj.aiTitle === "string") {
      sessionTitle = obj.aiTitle;
      continue;
    }
    // skill 호출시점 주입 본문 (isMeta user/text, 첫 줄 "Base directory for this skill:")
    if (obj.type === "user" && obj.isMeta === true) {
      const c = obj.message?.content;
      const text = Array.isArray(c) && c[0]?.type === "text" ? c[0].text : undefined;
      if (typeof text === "string") {
        const m = text.match(new RegExp(`^Base directory for this skill:\\s*(.+?)\\s*(?:${LINE_BREAK}|$)`));
        if (m) {
          const baseDir = m[1];
          const injectedBody = restorePluginRoot(stripBaseDirLine(text), baseDir);
          skillInvocations.push({
            name: basename(baseDir),
            baseDir,
            version: skillVersion(baseDir),
            hash: bodyHash(injectedBody),
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

// ── skill 본문 정규화 + 해시 (stale 판정용) ──
const LINE_BREAK = "(?:\\r\\n|\\n|\\r)";
const BASE_DIR_LINE = new RegExp(`^Base directory for this skill:.*${LINE_BREAK}+`);
// 슬래시 커맨드를 인자와 함께 호출하면 주입 본문 끝에 "ARGUMENTS: …" 블록이 덧붙는다.
// 이는 SKILL.md 본문이 아니라 호출 인자이므로 stale 해시 비교 전에 제거해야
// 같은 본문이 인자 유무/내용에 따라 stale로 오판되지 않는다.
const ARGUMENTS_TAIL = new RegExp(`${LINE_BREAK}${LINE_BREAK}ARGUMENTS:[\\s\\S]*$`);

// transcript 주입 본문에서 "Base directory" 첫 줄(+뒤 빈 줄)과 끝의 "ARGUMENTS:" 블록을 제거
function stripBaseDirLine(injected: string): string {
  return injected.replace(BASE_DIR_LINE, "").replace(ARGUMENTS_TAIL, "");
}

// 스킬 주입 시 Claude Code는 본문의 ${CLAUDE_PLUGIN_ROOT}를 plugin root 절대경로로 치환한다.
// 디스크 SKILL.md는 리터럴 ${CLAUDE_PLUGIN_ROOT}를 그대로 보존하므로, 동일 본문이라도
// 치환 여부 때문에 해시가 어긋나 false-stale로 dropped된다. 해싱 전에 치환을 되돌린다.
// plugin root = baseDir에서 끝의 "/skills/<name>"을 제거한 경로.
function restorePluginRoot(injectedBody: string, baseDir: string): string {
  const root = baseDir.replace(/[\\/]skills[\\/][^\\/]+[\\/]?$/, "");
  if (!root || root === baseDir) return injectedBody;
  return injectedBody.split(root).join("${CLAUDE_PLUGIN_ROOT}");
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
  return createHash("sha256").update(body.replace(/\r\n?/g, "\n").trim()).digest("hex");
}

function shortHash(hash: string): string {
  return hash.slice(0, 8);
}

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
  else arg = JSON.stringify(tu.input ?? {}).slice(0, 60);
  return arg ? `${name}: ${arg}` : name;
}

const BOOKKEEPING_TOOLS = new Set(["TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "AskUserQuestion"]);

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
  const args = prefix[2]?.trim();
  return args ? { name: prefix[1], args: args.slice(0, 200) } : { name: prefix[1] };
}

const PSEUDO_USER_PREFIXES = [
  "Base directory for this skill:",
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
function buildEvents(turns: Turn[]): Event[] {
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
        events.push({ t: t.index, kind: "error", tool: toolName, text: tr.content.slice(0, 200) });
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
        const cmd: string = tu.input?.command ?? "";
        const prefix = cmd.split(/\s+/).slice(0, 2).join(" ");
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
  // 정렬: 모든 events를 turn 기준 안정 정렬 (같은 turn 안에서는 emit 순서 유지)
  const combined = [...events, ...repeats];
  combined.sort((a, b) => a.t - b.t);
  return combined;
}

// ── summary: 얕은 탐색용 ───────────────────────────────
const SUMMARY_KINDS: EventKind[] = ["interrupt", "error", "repeat", "user"];
const CLUSTER_GAP = 30;
const CLUSTER_MIN = 3;

function buildClusters(events: Event[]): Cluster[] {
  const clusters: Cluster[] = [];
  for (const kind of SUMMARY_KINDS) {
    const turns = events.filter((e) => e.kind === kind).map((e) => e.t);
    if (turns.length < CLUSTER_MIN) continue;
    let start = turns[0];
    let prev = turns[0];
    let count = 1;
    for (let i = 1; i <= turns.length; i++) {
      const t = turns[i];
      if (t !== undefined && t - prev <= CLUSTER_GAP) {
        count++;
        prev = t;
        continue;
      }
      if (count >= CLUSTER_MIN) clusters.push({ kind, t_range: [start, prev], n: count, example_t: start });
      if (t === undefined) break;
      start = t;
      prev = t;
      count = 1;
    }
  }
  return clusters.sort((a, b) => a.t_range[0] - b.t_range[0]);
}

function buildHeadline(turns: number, events: Event[], clusters: Cluster[]): string {
  const counts: Record<string, number> = {};
  for (const e of events) counts[e.kind] = (counts[e.kind] ?? 0) + 1;
  const parts: string[] = [`${turns} turns`];
  for (const kind of ["user", "interrupt", "error", "repeat"] as const) {
    if (counts[kind]) parts.push(`${counts[kind]} ${kind}${counts[kind] > 1 ? "s" : ""}`);
  }
  if (clusters.length > 0) parts.push(`${clusters.length} cluster${clusters.length > 1 ? "s" : ""}`);
  return parts.join(" · ");
}

function buildSummary(turns: number, events: Event[]): Summary {
  const clusters = buildClusters(events);
  return {
    headline: buildHeadline(turns, events, clusters),
    clusters,
  };
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
  const { turns, sessionTitle } = loadTurns(jsonlPath);
  const events = buildEvents(turns);
  return {
    session_id: basename(jsonlPath, ".jsonl"),
    ...(sessionTitle ? { session_title: sessionTitle } : {}),
    turns: turns.length,
    summary: buildSummary(turns.length, events),
    events,
  };
}

// cwd에서 위로 올라가며 `plugins/` 를 가진 디렉터리(=이 repo 루트)를 찾는다.
function findRepoRoot(cwd: string): string | null {
  let dir = cwd;
  for (let i = 0; i < 30; i++) {
    if (existsSync(join(dir, "plugins"))) return dir;
    const parent = join(dir, "..");
    const resolved = resolve(parent);
    if (resolved === dir) break;
    dir = resolved;
  }
  return null;
}

// repo 안에서 같은 이름 skill의 편집 가능한 SKILL.md 경로를 찾는다 (plugins/*/skills/<name>/SKILL.md).
// transcript가 캐시 경로를 가리켜도, cwd repo에 그 skill 소스가 있으면 그걸 직접 편집 대상으로 쓴다.
function repoSkillPath(repoRoot: string | null, name: string): string | undefined {
  if (!repoRoot) return undefined;
  const pluginsDir = join(repoRoot, "plugins");
  if (!existsSync(pluginsDir)) return undefined;
  for (const plugin of readdirSync(pluginsDir).sort()) {
    const candidate = join(pluginsDir, plugin, "skills", name, "SKILL.md");
    if (existsSync(candidate)) return candidate;
  }
  return undefined;
}

function currentBodyHash(skillMd: string): string | null {
  if (!existsSync(skillMd)) return null;
  return bodyHash(stripFrontmatter(readFileSync(skillMd, "utf8")));
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

function formatRecentHeadline(sessionCount: number, skills: RecentSkill[]): string {
  const dropped = skills.filter((s) => s.dropped);
  let droppedPart = `${dropped.length} dropped`;
  if (dropped.length > 0) {
    const counts = new Map<string, number>();
    for (const skill of dropped) {
      if (!skill.drop_reason) continue;
      counts.set(skill.drop_reason, (counts.get(skill.drop_reason) ?? 0) + 1);
    }
    const reasons = [...counts.entries()].map(([reason, n]) => `${n} ${reason}`);
    if (reasons.length > 0) droppedPart += `: ${reasons.join(", ")}`;
  }
  return `${sessionCount} sessions · ${skills.length} skills · ${droppedPart}`;
}

function dropReasonFor(currentHash: string | null, hasCurrentBody: boolean): DropReason | undefined {
  if (hasCurrentBody) return undefined;
  return currentHash === null ? "missing_current_body" : "stale";
}

function buildRecentIndex(paths: string[], cwd: string): RecentIndex {
  const repoRoot = findRepoRoot(cwd);
  const sessions: RecentIndex["sessions"] = [];
  // name -> 누적 상태
  const acc = new Map<string, {
    baseDir: string;
    versionsByHash: Map<string, Set<string>>;
    seenByHash: Map<string, Set<string>>;
    seen: Set<string>;
    eventsByHash: Map<string, Event[]>;
  }>();

  for (const p of paths) {
    const sessionId = basename(p, ".jsonl");
    const { turns, sessionTitle, skillInvocations } = loadTurns(p);
    const events = buildEvents(turns);
    sessions.push({ session_id: sessionId, ...(sessionTitle ? { session_title: sessionTitle } : {}), turns: turns.length });

    // 이 세션에서 호출된 skill 이름 집합 + 호출시점 본문 해시
    const invokedNames = new Set<string>();
    const invokedHashesByName = new Map<string, Set<string>>();
    for (const inv of skillInvocations) {
      invokedNames.add(inv.name);
      getOrCreate(invokedHashesByName, inv.name, () => new Set()).add(inv.hash);
      const a = getOrCreate(acc, inv.name, () => ({
        baseDir: inv.baseDir,
        versionsByHash: new Map(),
        seenByHash: new Map(),
        seen: new Set(),
        eventsByHash: new Map(),
      }));
      // baseDir는 cache-only 현재 본문 조회를 위해 newest-first 입력에서 처음 관측한 호출 경로를 유지한다.
      a.seen.add(sessionId);
      getOrCreate(a.versionsByHash, inv.hash, () => new Set()).add(inv.version);
      getOrCreate(a.seenByHash, inv.hash, () => new Set()).add(sessionId);
      getOrCreate(a.eventsByHash, inv.hash, () => []);
    }

    // events를 해당 세션에서 호출된 skill의 호출시점 본문 해시로 귀속.
    // events의 session 식별을 위해 session 필드 마킹.
    for (const ev of events) {
      const tagged: Event = { ...ev, session: sessionId };
      // skill 이벤트는 그 세션에서 관측된 해당 skill의 모든 body hash에, 그 외 신호는 같은 세션에서 호출된 모든 skill hash에 귀속
      if (ev.kind === "skill" && ev.name) {
        const fallback = ev.name.includes(":") ? ev.name.split(":").pop()! : ev.name;
        const target = invokedHashesByName.has(ev.name) ? ev.name : fallback;
        const hashes = invokedHashesByName.get(target);
        if (!hashes) continue;
        for (const hash of hashes) acc.get(target)!.eventsByHash.get(hash)!.push(tagged);
      } else {
        for (const name of invokedNames) {
          for (const hash of invokedHashesByName.get(name) ?? []) acc.get(name)!.eventsByHash.get(hash)!.push(tagged);
        }
      }
    }
  }

  const skills: Array<RecentSkill & { _weight: number }> = [];
  for (const [name, a] of acc) {
    const cacheSkillMd = join(a.baseDir, "SKILL.md");
    // cwd repo에 같은 skill 소스가 있으면 그게 편집 가능한 "현재 본문"의 진짜 출처다 (캐시는 구버전일 수 있음).
    const repoPath = repoSkillPath(repoRoot, name);
    const nowHashFull = currentBodyHash(repoPath ?? cacheSkillMd);
    const hasCurrentBody = nowHashFull !== null && a.versionsByHash.has(nowHashFull);
    const summariesByHash = new Map(
      [...a.versionsByHash.keys()].map((hash) => [hash, summarizeSignal(a.eventsByHash.get(hash) ?? [])]),
    );
    const matchingEvents = hasCurrentBody ? a.eventsByHash.get(nowHashFull) ?? [] : [];
    const dropReason = dropReasonFor(nowHashFull, hasCurrentBody);
    const dropped = dropReason !== undefined;
    const stale = dropped;
    const evs = dropped ? [] : matchingEvents;
    const { signal, weight } = hasCurrentBody ? summariesByHash.get(nowHashFull)! : summarizeSignal([]);
    const observed_bodies = [...a.versionsByHash.keys()].sort().map((hash) => ({
      hash: shortHash(hash),
      current: hash === nowHashFull,
      versions: [...(a.versionsByHash.get(hash) ?? [])].sort(),
      seen_in: [...(a.seenByHash.get(hash) ?? [])].sort(),
      signal: summariesByHash.get(hash)!.signal,
    }));
    skills.push({
      name,
      skill_path: cacheSkillMd,
      ...(repoPath ? { repo_path: repoPath } : {}),
      ...(nowHashFull ? { current_hash: shortHash(nowHashFull) } : {}),
      ...(dropReason ? { drop_reason: dropReason } : {}),
      observed_bodies,
      stale,
      dropped,
      seen_in: [...a.seen].sort(),
      signal: dropped ? `dropped (${dropReason})` : signal,
      events: evs,
      _weight: weight,
    });
  }
  // 개선 신호(interrupt+error+repeat) 많은 순 → 동률이면 전체 event 수 순 → 이름순
  skills.sort((x, y) => y._weight - x._weight || y.events.length - x.events.length || x.name.localeCompare(y.name));
  for (const s of skills) delete (s as { _weight?: number })._weight;

  return {
    mode: "recent",
    session_count: sessions.length,
    sessions,
    skills,
    summary: { headline: formatRecentHeadline(sessions.length, skills) },
  };
}

// ── Phase 0: transcript 자동 탐지 ──────────────────────
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
  const projectsRoot = join(homedir(), ".claude", "projects");
  if (!existsSync(projectsRoot)) {
    console.error(`transcript directory not found: ${projectsRoot}`);
    process.exit(14);
  }
  // 같은 프로젝트의 모든 worktree 디렉터리를 합친다: base 자체 + base--worktrees-* 형제들.
  // bstack처럼 worktree마다 transcript가 쪼개지는 경우 "최근 N개 세션"이 전체에서 모이게.
  const base = projectBasePrefix(cwd);
  const dirs = readdirSync(projectsRoot).filter((d) => d === base || d.startsWith(base + "--worktrees-"));
  const files = dirs
    .flatMap((d) => jsonlFilesInDir(join(projectsRoot, d)))
    .sort((a, b) => b.mtime - a.mtime)
    .slice(0, n);
  if (files.length === 0) {
    console.error(`no .jsonl files for project ${base} (and its worktrees) under ${projectsRoot}`);
    process.exit(14);
  }
  return files.map((f) => f.path);
}

function transcriptProjectDir(cwd: string): string {
  return join(homedir(), ".claude", "projects", encodeCwd(cwd));
}

function latestTranscriptPathForCwd(cwd: string): string {
  const projectDir = transcriptProjectDir(cwd);
  if (!existsSync(projectDir)) {
    console.error(`transcript directory not found: ${projectDir}`);
    process.exit(14);
  }
  const files = jsonlFilesInDir(projectDir).sort((a, b) => b.mtime - a.mtime);
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
  const esc = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  // baseDir 마지막 세그먼트가 정확히 <name> 이어야 한다: …/skills/<name> 뒤에 / 또는 escape개행(\n) 또는 따옴표.
  const re = new RegExp(`Base directory for this skill:[^\\n"]*?/${esc}(?:/|\\\\n|")`);
  return re.test(text);
}

function skillNameCandidates(name: string): string[] {
  const short = name.includes(":") ? name.split(":").pop()! : name;
  return [...new Set([name, short])];
}

function findSkillSessionPaths(names: string[], n: number): string[] {
  const projectsRoot = join(homedir(), ".claude", "projects");
  if (!existsSync(projectsRoot)) {
    console.error(`transcript directory not found: ${projectsRoot}`);
    process.exit(14);
  }
  return readdirSync(projectsRoot)
    .flatMap((d) => {
      const full = join(projectsRoot, d);
      try {
        if (!statSync(full).isDirectory()) return [];
        return jsonlFilesInDir(full).map((f) => f.path);
      } catch {
        return [];
      }
    })
    .filter((p) => names.some((name) => transcriptInvokesSkill(p, name)))
    .map((p) => ({ path: p, mtime: statSync(p).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime)
    .slice(0, n)
    .map((f) => f.path);
}

function noSkillSessions(name: string): never {
  console.error(`no sessions invoking skill '${name}' found under ${join(homedir(), ".claude", "projects")}`);
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
  const index = buildRecentIndex(paths, targetCwd);
  // --skill 은 대상 스킬 하나로 좁혀서 내보낸다 (같은 세션의 다른 스킬은 제외).
  index.skills = index.skills.filter((s) => skillNames.includes(s.name));
  index.summary.headline = formatRecentHeadline(index.session_count, index.skills);
  console.log(JSON.stringify(index, null, 2));
} else if (opts.recent !== undefined) {
  const paths = recentSessionPaths(targetCwd, opts.recent);
  console.log(JSON.stringify(buildRecentIndex(paths, targetCwd), null, 2));
} else {
  const transcriptPath = resolveTranscriptPath({
    jsonlPath: opts.jsonlPath,
    sessionId: opts.sessionId,
    cwd: targetCwd,
  });
  console.log(JSON.stringify(buildIndex(transcriptPath), null, 2));
}
