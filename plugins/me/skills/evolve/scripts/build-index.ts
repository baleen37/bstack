#!/usr/bin/env bun
// build-index.ts — transcript jsonl을 SessionIndex JSON으로 변환
// 사용: bun build-index.ts [<jsonl-path>] [--session <id>] [--skill <name>]
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
  by?: "user" | "assistant";
  tool?: string;
  desc?: string;
  sub?: string;
  model?: string;
  bytes?: number;
  pattern?: string;
  n?: number;
}

interface SkillRun {
  name: string;
  turns: number[];
}

interface SessionIndex {
  session_id: string;
  session_title?: string;
  turns: number;
  tools_top: Array<[string, number]>;
  skill_runs: SkillRun[];
  signal_counts: Record<string, number>;
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

function priorAssistantActions(turns: Turn[], currentIdx: number): string[] {
  const actions: string[] = [];
  for (let i = currentIdx - 1; i >= 0 && actions.length < 3; i--) {
    const t = turns[i];
    if (t.type !== "assistant") continue;
    for (const tu of t.toolUses) {
      actions.push(summarizeToolUse(tu));
      if (actions.length >= 3) break;
    }
    if (actions.length > 0) break;
  }
  return actions;
}

// ── 슬래시 커맨드 검출 ──────────────────────────────────
const SLASH_CMD_TAG = /<command-name>\/([a-z0-9:_-]+)<\/command-name>/i;
const SLASH_CMD_PREFIX = /^\/([a-z0-9:_-]+)\b/i;

function detectSlashCommand(userText: string): string | undefined {
  const tag = userText.match(SLASH_CMD_TAG);
  if (tag) return tag[1];
  const prefix = userText.trim().match(SLASH_CMD_PREFIX);
  return prefix?.[1];
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
        const slashName = detectSlashCommand(t.userText);
        if (slashName) {
          events.push({ t: t.index, kind: "skill", name: slashName });
        } else {
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

// ── 부수 집계 ──────────────────────────────────────────
function buildSkillRuns(events: Event[]): SkillRun[] {
  const byName = new Map<string, number[]>();
  for (const e of events) {
    if (e.kind !== "skill" || !e.name) continue;
    if (!byName.has(e.name)) byName.set(e.name, []);
    byName.get(e.name)!.push(e.t);
  }
  return [...byName.entries()].map(([name, turns]) => ({ name, turns }));
}

function buildToolsTop(turns: Turn[]): Array<[string, number]> {
  const counts = new Map<string, number>();
  for (const t of turns) for (const tu of t.toolUses) counts.set(tu.name, (counts.get(tu.name) ?? 0) + 1);
  return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10);
}

function buildSignalCounts(events: Event[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const e of events) counts[e.kind] = (counts[e.kind] ?? 0) + 1;
  return counts;
}

// ── --skill 필터 ───────────────────────────────────────
function filterBySkill(index: SessionIndex, skillFilter: string): SessionIndex {
  const matching = index.skill_runs.find((r) => r.name === skillFilter);
  if (!matching || matching.turns.length === 0) {
    return { ...index, skill_runs: [], events: [], signal_counts: {} };
  }
  const firstTurn = matching.turns[0];
  const filteredEvents = index.events.filter((e) => e.t >= firstTurn);
  return {
    ...index,
    skill_runs: [matching],
    events: filteredEvents,
    signal_counts: buildSignalCounts(filteredEvents),
  };
}

function buildIndex(jsonlPath: string, skillFilter?: string): SessionIndex {
  const { turns, sessionTitle } = loadTurns(jsonlPath);
  const events = buildEvents(turns);
  const index: SessionIndex = {
    session_id: basename(jsonlPath, ".jsonl"),
    ...(sessionTitle ? { session_title: sessionTitle } : {}),
    turns: turns.length,
    tools_top: buildToolsTop(turns),
    skill_runs: buildSkillRuns(events),
    signal_counts: buildSignalCounts(events),
    events,
  };
  return skillFilter ? filterBySkill(index, skillFilter) : index;
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
function parseArgs(argv: string[]): { jsonlPath?: string; sessionId?: string; skill?: string } {
  const args = argv.slice(2);
  let jsonlPath: string | undefined;
  let sessionId: string | undefined;
  let skill: string | undefined;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--skill") skill = args[++i];
    else if (args[i] === "--session") sessionId = args[++i];
    else if (!jsonlPath) jsonlPath = args[i];
    else {
      console.error(`unexpected argument: ${args[i]}`);
      process.exit(2);
    }
  }
  return { jsonlPath, sessionId, skill };
}

const opts = parseArgs(process.argv);
const transcriptPath = resolveTranscriptPath({
  jsonlPath: opts.jsonlPath,
  sessionId: opts.sessionId,
  cwd: process.cwd(),
});
console.log(JSON.stringify(buildIndex(transcriptPath, opts.skill), null, 2));
