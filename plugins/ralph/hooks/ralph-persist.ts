#!/usr/bin/env bun
import { existsSync, readFileSync, writeFileSync, unlinkSync, mkdirSync } from "fs";
import { join } from "path";

const STALE_MS = 2 * 60 * 60 * 1000; // 2 hours

function allow(): never { process.exit(0); }

function block(iter: number, max: number, prompt: string): never {
  process.stdout.write(JSON.stringify({
    decision: "block",
    reason: `[RALPH LOOP - ITERATION ${iter}/${max}] Work is not done. Continue working on the task: ${prompt}`,
  }));
  process.exit(0);
}

async function main() {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
  const input = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");

  const cwd = input.cwd ?? process.cwd();
  const sessionId = input.session_id ?? "";
  const dir = join(cwd, ".ralph", "state");
  const statePath = join(dir, "ralph-state.json");
  const sentinel = join(dir, "ralph-activating");
  const cancelPath = join(dir, "cancel-signal-state.json");

  // Activation: sentinel exists but no state yet
  if (existsSync(sentinel) && !existsSync(statePath)) {
    const prompt = readFileSync(sentinel, "utf8").trim();
    unlinkSync(sentinel);
    const now = new Date().toISOString();
    const state = { active: true, session_id: sessionId, iteration: 1, max_iterations: 10, started_at: now, last_checked_at: now, prompt };
    mkdirSync(dir, { recursive: true });
    writeFileSync(statePath, JSON.stringify(state, null, 2));
    block(1, 10, prompt);
  }

  // Load state — pass through if missing or inactive
  let state: any;
  try { state = JSON.parse(readFileSync(statePath, "utf8")); } catch { allow(); }
  if (!state?.active) allow();

  // Session mismatch — don't interfere with other sessions
  if (state.session_id && sessionId && state.session_id !== sessionId) allow();

  // Cancel signal — clean up and allow exit
  if (existsSync(cancelPath)) {
    unlinkSync(cancelPath);
    state.active = false;
    writeFileSync(statePath, JSON.stringify(state, null, 2));
    allow();
  }

  // Stale state (>2h) — auto-disable
  if (Date.now() - new Date(state.last_checked_at).getTime() > STALE_MS) {
    state.active = false;
    writeFileSync(statePath, JSON.stringify(state, null, 2));
    allow();
  }

  // Block: increment iteration, extend max if needed
  if (state.iteration >= state.max_iterations) state.max_iterations += 10;
  state.iteration += 1;
  state.last_checked_at = new Date().toISOString();
  writeFileSync(statePath, JSON.stringify(state, null, 2));
  block(state.iteration, state.max_iterations, state.prompt);
}

main().catch((err) => {
  process.stderr.write(`ralph-persist error: ${err}\n`);
  process.exit(0); // Never crash Claude
});
