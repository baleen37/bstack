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

// ── 신호 추출: D. success_pattern ──────────────────────
const POSITIVE = /^(좋아|perfect|그렇지|yes|ok|good|great)(\s|$)/i;

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

// ── 통계: tools_top ────────────────────────────────────
function buildToolsTop(turns: Turn[]): Array<[string, number]> {
  const counts = new Map<string, number>();
  for (const t of turns) for (const tu of t.toolUses) counts.set(tu.name, (counts.get(tu.name) ?? 0) + 1);
  return [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 10);
}

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

// ── stub: 나머지는 후속 task에서 채움 ──────────────────
function buildIndex(jsonlPath: string, skillFilter?: string): SessionIndex {
  const turns = loadTurns(jsonlPath);
  const corrections = extractUserCorrections(turns, jsonlPath);
  const verbose = extractVerboseExploration(turns, jsonlPath, corrections.length);
  const success = extractSuccessPatterns(turns, jsonlPath, corrections.length + verbose.length);
  const allSignals = [...corrections, ...verbose, ...success];
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
  return {
    session_id: basename(jsonlPath, ".jsonl"),
    jsonl_path: jsonlPath,
    turns_total: turns.length,
    user_messages: turns.filter((t) => t.userText !== undefined).length,
    interrupts_total: turns.filter((t) => t.interrupted).length,
    tools_top: buildToolsTop(turns),
    skill_invocations: [],
    groups,
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
