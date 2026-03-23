#!/usr/bin/env bun
import { existsSync, readFileSync, writeFileSync, unlinkSync, mkdirSync } from "fs";
import { join } from "path";

const STALE_THRESHOLD_MS = 2 * 60 * 60 * 1000; // 2 hours

interface HookInput {
  session_id?: string;
  cwd?: string;
  hook_event_name?: string;
}

interface RalphState {
  active: boolean;
  session_id: string;
  iteration: number;
  max_iterations: number;
  started_at: string;
  last_checked_at: string;
  prompt: string;
}

function readState(stateDir: string): RalphState | null {
  const path = join(stateDir, "ralph-state.json");
  if (!existsSync(path)) return null;
  try {
    return JSON.parse(readFileSync(path, "utf8")) as RalphState;
  } catch {
    return null;
  }
}

function writeState(stateDir: string, state: RalphState): void {
  mkdirSync(stateDir, { recursive: true });
  writeFileSync(join(stateDir, "ralph-state.json"), JSON.stringify(state, null, 2));
}

function allow(): void {
  // Write nothing, exit 0
  process.exit(0);
}

function block(iteration: number, maxIterations: number, prompt: string): void {
  process.stdout.write(
    JSON.stringify({
      decision: "block",
      reason: `[RALPH LOOP - ITERATION ${iteration}/${maxIterations}] Work is not done. Continue working on the task: ${prompt}`,
    })
  );
  process.exit(0);
}

async function main(): Promise<void> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk as Buffer);
  }
  const input: HookInput = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");

  const cwd = input.cwd ?? process.cwd();
  const sessionId = input.session_id ?? "";
  const stateDir = join(cwd, ".ralph", "state");

  // Check activation sentinel
  const activatingSentinel = join(stateDir, "ralph-activating");
  if (existsSync(activatingSentinel) && !existsSync(join(stateDir, "ralph-state.json"))) {
    const prompt = readFileSync(activatingSentinel, "utf8").trim();
    unlinkSync(activatingSentinel);
    const now = new Date().toISOString();
    const state: RalphState = {
      active: true,
      session_id: sessionId,
      iteration: 0,
      max_iterations: 100,
      started_at: now,
      last_checked_at: now,
      prompt,
    };
    writeState(stateDir, state);
    block(1, state.max_iterations, state.prompt);
    return;
  }

  const state = readState(stateDir);

  // Pass-through: no state
  if (!state) {
    allow();
    return;
  }

  // Pass-through: inactive
  if (!state.active) {
    allow();
    return;
  }

  // Pass-through: session mismatch
  if (state.session_id && sessionId && state.session_id !== sessionId) {
    allow();
    return;
  }

  // Pass-through: cancel signal
  const cancelSignal = join(stateDir, "cancel-signal-state.json");
  if (existsSync(cancelSignal)) {
    unlinkSync(cancelSignal);
    state.active = false;
    writeState(stateDir, state);
    allow();
    return;
  }

  // Pass-through: stale state
  const lastChecked = new Date(state.last_checked_at).getTime();
  if (Date.now() - lastChecked > STALE_THRESHOLD_MS) {
    state.active = false;
    writeState(stateDir, state);
    allow();
    return;
  }

  // Block: extend max_iterations if needed, then block
  if (state.iteration >= state.max_iterations) {
    state.max_iterations += 10;
  }
  state.iteration += 1;
  state.last_checked_at = new Date().toISOString();
  writeState(stateDir, state);
  block(state.iteration, state.max_iterations, state.prompt);
}

main().catch((err) => {
  process.stderr.write(`ralph-persist error: ${err}\n`);
  process.exit(0); // Always exit 0 — never crash Claude
});
