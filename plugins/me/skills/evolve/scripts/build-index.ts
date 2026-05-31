#!/usr/bin/env bun
// build-index.ts — transcript jsonl을 SessionIndex JSON으로 변환
// 사용: bun build-index.ts [<jsonl-path>] [--session <id>]
// 출력: stdout에 JSON

import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { homedir } from "node:os";
import { createHash } from "node:crypto";

// ── 타입 ───────────────────────────────────────────────
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

interface RecentSkill {
  name: string;
  skill_path: string;     // transcript가 가리킨 호출 시점 base 경로의 SKILL.md (보통 캐시 경로)
  repo_path?: string;     // cwd repo 안에서 찾은 편집 가능한 SKILL.md (있으면 직접 edit 대상)
  stale: boolean;         // 세션 이후 본문 변경 여부
  dropped: boolean;       // stale 또는 파일없음 → events 제외됨
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
  injectedBody: string;  // "Base directory" 줄 제거 후의 본문 (해시 입력)
}

interface LoadedTranscript {
  turns: Turn[];
  sessionTitle?: string;
  skillInvocations: SkillInvocation[];
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
  return createHash("sha256").update(body.trim()).digest("hex");
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
        if (!bashOccur.has(prefix)) bashOccur.set(prefix, []);
        bashOccur.get(prefix)!.push(t.index);
      } else if (tu.name === "Read") {
        const p: string = tu.input?.file_path ?? "";
        if (!p) continue;
        if (!readOccur.has(p)) readOccur.set(p, []);
        readOccur.get(p)!.push(t.index);
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
  for (const plugin of readdirSync(pluginsDir)) {
    const candidate = join(pluginsDir, plugin, "skills", name, "SKILL.md");
    if (existsSync(candidate)) return candidate;
  }
  return undefined;
}

function currentBodyHash(skillMd: string): string | null {
  if (!existsSync(skillMd)) return null;
  return bodyHash(stripFrontmatter(readFileSync(skillMd, "utf8")));
}

function buildRecentIndex(paths: string[], cwd: string): RecentIndex {
  const repoRoot = findRepoRoot(cwd);
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
    // events의 session 식별을 위해 session 필드 마킹.
    for (const ev of events) {
      const tagged: Event = { ...ev, session: sessionId };
      // skill 이벤트는 그 skill에, 그 외 신호는 같은 세션에서 호출된 모든 skill에 귀속
      if (ev.kind === "skill" && ev.name) {
        const short = ev.name.includes(":") ? ev.name.split(":").pop()! : ev.name;
        if (acc.has(short)) acc.get(short)!.events.push(tagged);
      } else {
        for (const name of invokedNames) acc.get(name)!.events.push(tagged);
      }
    }
  }

  // kind별 카운트 → 한 줄 요약. interrupt/error/repeat은 개선 신호가 농축된 종류라 앞세운다.
  function summarizeSignal(events: Event[]): { signal: string; weight: number } {
    const c: Record<string, number> = {};
    for (const e of events) c[e.kind] = (c[e.kind] ?? 0) + 1;
    const order: EventKind[] = ["interrupt", "error", "repeat", "user", "agent", "skill"];
    const parts = order.filter((k) => c[k]).map((k) => `${c[k]} ${k}`);
    const weight = (c["interrupt"] ?? 0) + (c["error"] ?? 0) + (c["repeat"] ?? 0);
    return { signal: parts.length ? parts.join(", ") : "no events", weight };
  }

  const skills: Array<RecentSkill & { _weight: number }> = [];
  for (const [name, a] of acc) {
    const cacheSkillMd = join(a.baseDir, "SKILL.md");
    // cwd repo에 같은 skill 소스가 있으면 그게 편집 가능한 "현재 본문"의 진짜 출처다 (캐시는 구버전일 수 있음).
    const repoPath = repoSkillPath(repoRoot, name);
    const nowHash = currentBodyHash(repoPath ?? cacheSkillMd);
    // stale = 현재 본문이 호출시점 본문들 중 어느 것과도 일치하지 않음
    const stale = nowHash === null ? true : !a.invokedHashes.has(nowHash);
    const dropped = stale;
    const evs = dropped ? [] : a.events;
    const { signal, weight } = summarizeSignal(evs);
    skills.push({
      name,
      skill_path: cacheSkillMd,
      ...(repoPath ? { repo_path: repoPath } : {}),
      stale,
      dropped,
      seen_in: [...a.seen],
      signal: dropped ? "dropped (stale)" : signal,
      events: evs,
      _weight: weight,
    });
  }
  // 개선 신호(interrupt+error+repeat) 많은 순 → 동률이면 전체 event 수 순
  skills.sort((x, y) => y._weight - x._weight || y.events.length - x.events.length);
  for (const s of skills) delete (s as { _weight?: number })._weight;

  const droppedN = skills.filter((s) => s.dropped).length;
  return {
    mode: "recent",
    session_count: sessions.length,
    sessions,
    skills,
    summary: { headline: `${sessions.length} sessions · ${skills.length} skills · ${droppedN} dropped` },
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
    .flatMap((d) => {
      const full = join(projectsRoot, d);
      try {
        return readdirSync(full)
          .filter((f) => f.endsWith(".jsonl"))
          .map((f) => ({ path: join(full, f), mtime: statSync(join(full, f)).mtimeMs }));
      } catch {
        return [];
      }
    })
    .sort((a, b) => b.mtime - a.mtime)
    .slice(0, n);
  if (files.length === 0) {
    console.error(`no .jsonl files for project ${base} (and its worktrees) under ${projectsRoot}`);
    process.exit(14);
  }
  return files.map((f) => f.path);
}

function resolveTranscriptPath(opts: { jsonlPath?: string; sessionId?: string; cwd: string }): string {
  if (opts.jsonlPath) return resolve(opts.jsonlPath);
  const encoded = encodeCwd(opts.cwd);
  const projectDir = join(homedir(), ".claude", "projects", encoded);
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
  const files = readdirSync(projectDir)
    .filter((f) => f.endsWith(".jsonl"))
    .map((f) => ({ path: join(projectDir, f), mtime: statSync(join(projectDir, f)).mtimeMs }))
    .sort((a, b) => b.mtime - a.mtime);
  if (files.length === 0) {
    console.error(`no .jsonl files in ${projectDir}`);
    process.exit(14);
  }
  return files[0].path;
}

// ── 진입점 ─────────────────────────────────────────────
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

const opts = parseArgs(process.argv);
if (opts.recent !== undefined) {
  const paths = recentSessionPaths(process.cwd(), opts.recent);
  console.log(JSON.stringify(buildRecentIndex(paths, process.cwd()), null, 2));
} else {
  const transcriptPath = resolveTranscriptPath({
    jsonlPath: opts.jsonlPath,
    sessionId: opts.sessionId,
    cwd: process.cwd(),
  });
  console.log(JSON.stringify(buildIndex(transcriptPath), null, 2));
}
