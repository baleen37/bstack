#!/usr/bin/env bun
// build-index.ts — transcript jsonl을 SessionIndex JSON으로 변환
// 사용: bun build-index.ts <jsonl-path> [--skill <name>]
// 출력: stdout에 JSON

import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { homedir } from "node:os";

// ── 타입 ───────────────────────────────────────────────
// SignalKind 의도적으로 좁힘: 인덱서는 결정적 메타데이터만, 의미 분류는 LLM 책임.
type SignalKind =
  | "user_message"           // 사용자 발화 (LLM이 분류)
  | "verbose_exploration"    // 같은 명령 N회 반복 (사실 카운트)
  | "interrupt";             // interrupt 마커 (메타데이터)

interface Signal {
  id: string;
  kind: SignalKind;
  turn_range: [number, number];
  snippet: string;
  detail?: string;
  prior_actions?: string[];  // user_message일 때만: 직전 assistant 행동 요약
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
      interrupted: obj.message?.stop_reason === "interrupted" || obj.interruptedMessageId !== undefined,
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

// ── 신호 수집: A. user_message ─────────────────────────
// 모든 user 발화를 raw signal로 emit. 분류 (정정/긍정/질문/잡담)는 LLM이 함.
// 직전 assistant 행동을 prior_actions로 묶어 문맥 제공.
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

function summarizePriorActions(turns: Turn[], currentIdx: number): string[] {
  const actions: string[] = [];
  for (let i = currentIdx - 1; i >= 0 && actions.length < 3; i--) {
    const t = turns[i];
    if (t.type !== "assistant") continue;
    for (const tu of t.toolUses) {
      actions.push(summarizeToolUse(tu));
      if (actions.length >= 3) break;
    }
    if (actions.length > 0) break; // 가장 인접한 assistant turn 하나만
  }
  return actions;
}

function collectUserMessages(turns: Turn[], jsonlPath: string): Signal[] {
  const signals: Signal[] = [];
  let counter = 0;
  for (let i = 0; i < turns.length; i++) {
    const t = turns[i];
    if (!t.userText) continue;
    counter++;
    signals.push({
      id: `S${counter}`,
      kind: "user_message",
      turn_range: [t.index, t.index],
      snippet: t.userText.trim().slice(0, 200),
      prior_actions: summarizePriorActions(turns, i),
      context_pointer: { jsonl_path: jsonlPath, turn_range: [Math.max(1, t.index - 2), t.index] },
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

// ── skill invocations ──────────────────────────────────
// Claude Code transcript 안에서 슬래시 커맨드는 두 가지 모양으로 등장한다:
//   1) <command-name>/me:browse</command-name> 태그 (자동 expand된 경우)
//   2) 사용자가 직접 친 "/me:browse 잘 동작해?" 같은 prefix
const SLASH_CMD_TAG = /<command-name>\/([a-z0-9:_-]+)<\/command-name>/i;
const SLASH_CMD_PREFIX = /^\/([a-z0-9:_-]+)\b/i;

function extractSkillInvocations(turns: Turn[]): SkillInvocation[] {
  const invs: SkillInvocation[] = [];
  for (const t of turns) {
    if (!t.userText) continue;
    const text = t.userText;
    const tagMatch = text.match(SLASH_CMD_TAG);
    const prefixMatch = text.trim().match(SLASH_CMD_PREFIX);
    const name = tagMatch?.[1] ?? prefixMatch?.[1];
    if (!name) continue;
    invs.push({ name, turn: t.index, outcome: "completed" });
  }
  return invs;
}

// ── 신호 추출: B. interrupt ────────────────────────────
// Interrupt 마커는 transcript에 두 모양으로 등장한다:
//   1) user turn에 interruptedMessageId — 실제 사용자가 끊은 경우 (가장 흔함)
//   2) assistant turn에 stop_reason="interrupted" — 일부 환경에서 등장
// 두 경우 모두 signal로 잡되, 같은 turn 묶음을 중복 발행하지 않는다.
function extractInterrupts(turns: Turn[], jsonlPath: string, startId: number): Signal[] {
  const signals: Signal[] = [];
  let counter = startId;
  const claimedTurns = new Set<number>();
  for (const t of turns) {
    if (!t.interrupted) continue;
    if (claimedTurns.has(t.index)) continue;
    counter++;
    if (t.type === "user") {
      // user turn이 인터럽트 마커를 들고 있음 → 직전 assistant 행동을 컨텍스트로
      const prevAssist = [...turns].reverse().find((a) => a.index < t.index && a.type === "assistant");
      const winStart = prevAssist ? prevAssist.index : t.index;
      claimedTurns.add(t.index);
      if (prevAssist) claimedTurns.add(prevAssist.index);
      signals.push({
        id: `S${counter}`,
        kind: "interrupt",
        turn_range: [winStart, t.index],
        snippet: t.userText?.trim().slice(0, 80) ?? "(interrupted)",
        detail: "user interrupted the prior assistant turn",
        context_pointer: { jsonl_path: jsonlPath, turn_range: [winStart, t.index] },
      });
    } else {
      // assistant stop_reason="interrupted" 경로 — 직전 user 발화를 컨텍스트로
      const prevUser = [...turns].reverse().find((u) => u.index < t.index && u.userText);
      const winStart = prevUser ? prevUser.index : t.index;
      claimedTurns.add(t.index);
      if (prevUser) claimedTurns.add(prevUser.index);
      signals.push({
        id: `S${counter}`,
        kind: "interrupt",
        turn_range: [winStart, t.index],
        snippet: prevUser?.userText?.trim().slice(0, 80) ?? "(no prior user message)",
        detail: "assistant turn was interrupted",
        context_pointer: { jsonl_path: jsonlPath, turn_range: [winStart, t.index] },
      });
    }
  }
  return signals;
}

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

function buildIndex(jsonlPath: string, skillFilter?: string): SessionIndex {
  const turns = loadTurns(jsonlPath);
  const userMsgs = collectUserMessages(turns, jsonlPath);
  const verbose = extractVerboseExploration(turns, jsonlPath, userMsgs.length);
  const interrupts = extractInterrupts(turns, jsonlPath, userMsgs.length + verbose.length);
  const allSignals = [...userMsgs, ...verbose, ...interrupts];
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

// ── Phase 0: transcript 자동 탐지 ──────────────────────
function encodeCwd(cwd: string): string {
  // Claude Code project dir naming: '/' and '.' both become '-'
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
  // newest .jsonl in projectDir
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
// 인덱서는 read-only — dirty tree 가드는 apply-patch.sh가 책임진다.
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
