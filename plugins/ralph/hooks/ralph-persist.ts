#!/usr/bin/env bun
import { existsSync, readFileSync, writeFileSync, unlinkSync, mkdirSync } from "fs";
import { join } from "path";

const STALE_MS = 7_200_000; // 2h

function allow(): never { process.exit(0); }
function block(i: number, m: number, p: string, cwd: string): never {
  let progress = "";
  try {
    const prd = JSON.parse(readFileSync(join(cwd, ".ralph", "prd.json"), "utf8"));
    const stories = prd.userStories || [];
    const done = stories.filter((s: any) => s.passes).length;
    progress = ` (${done}/${stories.length} stories done)`;
  } catch {}
  let lastFail = "";
  try {
    const lines = readFileSync(join(cwd, ".ralph", "progress.txt"), "utf8").trim().split("\n");
    lastFail = ` Last: ${lines[lines.length - 1]}`;
  } catch {}
  process.stdout.write(JSON.stringify({ decision: "block", reason: `[RALPH ${i}/${m}]${progress}${lastFail} Continue: ${p}` }));
  process.exit(0);
}

async function main() {
  const buf: Buffer[] = [];
  for await (const c of process.stdin) buf.push(c as Buffer);
  const input = JSON.parse(Buffer.concat(buf).toString() || "{}");
  const cwd = input.cwd ?? process.cwd();
  const sid = input.session_id ?? "";
  const dir = join(cwd, ".ralph", "state");
  const sp = join(dir, "ralph-state.json");
  const save = (s: any) => writeFileSync(sp, JSON.stringify(s, null, 2));
  const off = (s: any) => { s.active = false; save(s); allow(); };

  const sentinel = join(dir, "ralph-activating");
  if (existsSync(sentinel) && !existsSync(sp)) {
    const p = readFileSync(sentinel, "utf8").trim();
    unlinkSync(sentinel);
    const now = new Date().toISOString();
    mkdirSync(dir, { recursive: true });
    save({ active: true, session_id: sid, iteration: 1, max_iterations: 10, started_at: now, last_checked_at: now, prompt: p });
    block(1, 10, p, cwd);
  }

  let s: any;
  try { s = JSON.parse(readFileSync(sp, "utf8")); } catch { allow(); }
  if (!s?.active) allow();
  if (s.session_id && sid && s.session_id !== sid) allow();
  if (existsSync(join(dir, "cancel-signal-state.json"))) { unlinkSync(join(dir, "cancel-signal-state.json")); off(s); }
  if (Date.now() - new Date(s.last_checked_at).getTime() > STALE_MS) off(s);

  if (s.iteration >= s.max_iterations) s.max_iterations += 10;
  s.iteration += 1;
  s.last_checked_at = new Date().toISOString();
  save(s);
  block(s.iteration, s.max_iterations, s.prompt, cwd);
}

main().catch((e) => { process.stderr.write(`ralph-persist: ${e}\n`); process.exit(0); });
