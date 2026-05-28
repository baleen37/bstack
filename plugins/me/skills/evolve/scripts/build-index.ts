#!/usr/bin/env bun
// build-index.ts — transcript jsonl을 SessionIndex JSON으로 변환
// 사용: bun build-index.ts [<jsonl-path>] [--session <id>]
// 출력: stdout에 JSON

import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { homedir } from "node:os";

// ── 타입 ───────────────────────────────────────────────
type EventKind = "user" | "skill" | "interrupt" | "error" | "agent" | "large_out" | "repeat";

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
  bytes?: number;
  pattern?: string;
  n?: number;
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
  signal_positions: Partial<Record<EventKind, number[]>>;
}

interface SessionIndex {
  session_id: string;
  session_title?: string;
  turns: number;
  summary: Summary;
  events: Event[];
}

// ── 입력 파싱 ──────────────────────────────────────────
interface ToolResultPayload {
  content: string;
  isError: boolean;
  size: number;
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

interface LoadedTranscript {
  turns: Turn[];
  sessionTitle?: string;
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
  let sessionTitle: string | undefined;
  for (const line of lines) {
    const obj = JSON.parse(line);
    if (obj.type === "ai-title" && typeof obj.aiTitle === "string") {
      sessionTitle = obj.aiTitle;
      continue;
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
            t.toolResults.push({ content: norm, isError: c.is_error === true, size: norm.length });
          }
        }
      }
    } else if (Array.isArray(content)) {
      for (const c of content) if (c.type === "tool_use") t.toolUses.push({ name: c.name, input: c.input });
    }
    turns.push(t);
  }
  return { turns, sessionTitle };
}

// ── tool_use 요약 (user.prior, large_out.tool에 사용) ──
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
];

function isPseudoUser(userText: string): boolean {
  const trimmed = userText.trimStart();
  return PSEUDO_USER_PREFIXES.some((p) => trimmed.startsWith(p));
}

// ── events 빌드 ────────────────────────────────────────
const LARGE_OUTPUT_THRESHOLD = 10 * 1024;

function buildEvents(turns: Turn[]): Event[] {
  const events: Event[] = [];
  const interruptClaimed = new Set<number>();

  // user / skill / interrupt(user) / error / agent / large_out 를 순회 중에 emit
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
      // tool_result 안의 error / large_out
      for (const tr of t.toolResults) {
        const prevAssist = [...turns.slice(0, i)].reverse().find((a) => a.type === "assistant" && a.toolUses.length > 0);
        const toolName = prevAssist?.toolUses[prevAssist.toolUses.length - 1]?.name ?? "unknown";
        if (tr.isError) {
          events.push({ t: t.index, kind: "error", tool: toolName, text: tr.content.slice(0, 200) });
        }
        if (tr.size > LARGE_OUTPUT_THRESHOLD) {
          events.push({ t: t.index, kind: "large_out", tool: toolName, bytes: tr.size });
        }
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

function buildSignalPositions(events: Event[]): Partial<Record<EventKind, number[]>> {
  const out: Partial<Record<EventKind, number[]>> = {};
  for (const kind of SUMMARY_KINDS) {
    const turns = events.filter((e) => e.kind === kind).map((e) => e.t);
    if (turns.length > 0) out[kind] = turns;
  }
  return out;
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
    signal_positions: buildSignalPositions(events),
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

// ── Phase 0: transcript 자동 탐지 ──────────────────────
function encodeCwd(cwd: string): string {
  return cwd.replace(/[/.]/g, "-");
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
function parseArgs(argv: string[]): { jsonlPath?: string; sessionId?: string } {
  const args = argv.slice(2);
  let jsonlPath: string | undefined;
  let sessionId: string | undefined;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--session") sessionId = args[++i];
    else if (!jsonlPath) jsonlPath = args[i];
    else {
      console.error(`unexpected argument: ${args[i]}`);
      process.exit(2);
    }
  }
  return { jsonlPath, sessionId };
}

const opts = parseArgs(process.argv);
const transcriptPath = resolveTranscriptPath({
  jsonlPath: opts.jsonlPath,
  sessionId: opts.sessionId,
  cwd: process.cwd(),
});
console.log(JSON.stringify(buildIndex(transcriptPath), null, 2));
