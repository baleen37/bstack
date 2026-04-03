#!/usr/bin/env bun
import { existsSync, readFileSync, writeFileSync, unlinkSync, mkdirSync } from "fs";
import { join } from "path";

const STALE_MS = 2 * 60 * 60 * 1000;

function allow(): never { process.exit(0); }
function block(iter: number, max: number, prompt: string): never {
  process.stdout.write(JSON.stringify({ decision: "block", reason: `[RALPH LOOP - ITERATION ${iter}/${max}] Work is not done. Continue: ${prompt}` }));
  process.exit(0);
}

async function main() {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
  const input = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");

  const cwd = input.cwd ?? process.cwd();
  const sid = input.session_id ?? "";
  const dir = join(cwd, ".ralph", "state");
  const sp = join(dir, "ralph-state.json");
  const save = (s: any) => writeFileSync(sp, JSON.stringify(s, null, 2));
  const deactivate = (s: any) => { s.active = false; save(s); allow(); };

  // Activation
  const sentinel = join(dir, "ralph-activating");
  if (existsSync(sentinel) && !existsSync(sp)) {
    const prompt = readFileSync(sentinel, "utf8").trim();
    unlinkSync(sentinel);
    const now = new Date().toISOString();
    mkdirSync(dir, { recursive: true });
    save({ active: true, session_id: sid, iteration: 1, max_iterations: 10, started_at: now, last_checked_at: now, prompt });
    block(1, 10, prompt);
  }

  let state: any;
  try { state = JSON.parse(readFileSync(sp, "utf8")); } catch { allow(); }
  if (!state?.active) allow();
  if (state.session_id && sid && state.session_id !== sid) allow();

  const cancel = join(dir, "cancel-signal-state.json");
  if (existsSync(cancel)) { unlinkSync(cancel); deactivate(state); }
  if (Date.now() - new Date(state.last_checked_at).getTime() > STALE_MS) deactivate(state);

  if (state.iteration >= state.max_iterations) state.max_iterations += 10;
  state.iteration += 1;
  state.last_checked_at = new Date().toISOString();
  save(state);
  block(state.iteration, state.max_iterations, state.prompt);
}

main().catch((e) => { process.stderr.write(`ralph-persist error: ${e}\n`); process.exit(0); });
