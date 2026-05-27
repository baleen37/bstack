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
