import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";

import type { RuntimeName } from "./evaluator";

export interface RuntimeRequest {
  runtime: RuntimeName;
  systemPrompt: string;
  userPrompt: string;
  schema: object;
  workingDirectory: string;
}

export interface RuntimeResult {
  exitCode: number;
  stdoutLines: string[];
  stderr: string;
  finalJson: unknown;
  elapsedMs: number;
  availability: "available" | "missing_cli" | "auth_unavailable";
}

function lines(text: string): string[] {
  return text.split(/\r?\n/).filter((line) => line.trim() !== "");
}

function availabilityFor(exitCode: number, stderr: string): RuntimeResult["availability"] {
  if (exitCode !== 0 && /authentication|unauthorized|login|API key|OAuth/i.test(stderr)) {
    return "auth_unavailable";
  }
  return "available";
}

async function spawn(
  command: string[],
  input: string | undefined,
  workingDirectory: string,
): Promise<Omit<RuntimeResult, "finalJson" | "elapsedMs">> {
  try {
    const child = Bun.spawn(command, {
      cwd: workingDirectory,
      stdin: input === undefined ? "ignore" : "pipe",
      stdout: "pipe",
      stderr: "pipe",
    });
    if (input !== undefined) {
      child.stdin.write(input);
      child.stdin.end();
    }
    const [stdout, stderr, exitCode] = await Promise.all([
      new Response(child.stdout).text(),
      new Response(child.stderr).text(),
      child.exited,
    ]);
    return {
      exitCode,
      stdoutLines: lines(stdout),
      stderr,
      availability: availabilityFor(exitCode, stderr),
    };
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return {
      exitCode: 127,
      stdoutLines: [],
      stderr: detail,
      availability: "missing_cli",
    };
  }
}

function parseClaudeResult(stdoutLines: string[]): unknown {
  let result: Record<string, unknown> | undefined;
  for (const line of stdoutLines) {
    const value = JSON.parse(line) as unknown;
    if (typeof value === "object" && value !== null && !Array.isArray(value)
      && (value as Record<string, unknown>).type === "result") {
      result = value as Record<string, unknown>;
    }
  }
  if (!result) throw new Error("Claude stream did not include a result event");
  if ("structured_output" in result) return result.structured_output;
  if (typeof result.result !== "string") throw new Error("Claude result did not include JSON output");
  return JSON.parse(result.result);
}

export async function runStructured(request: RuntimeRequest): Promise<RuntimeResult> {
  const startedAt = performance.now();
  const temporaryDirectory = await mkdtemp(join(tmpdir(), "research-eval-"));
  try {
    if (request.runtime === "codex") {
      const schemaPath = join(temporaryDirectory, "schema.json");
      const answerPath = join(temporaryDirectory, "answer.json");
      const emptyDirectory = join(temporaryDirectory, "workspace");
      await Promise.all([
        writeFile(schemaPath, JSON.stringify(request.schema)),
        mkdir(emptyDirectory),
      ]);
      const result = await spawn([
        process.env.RESEARCH_EVAL_CODEX_BIN ?? "codex",
        "exec",
        "--ephemeral",
        "--ignore-user-config",
        "--sandbox", "read-only",
        "--skip-git-repo-check",
        "--json",
        "--output-schema", schemaPath,
        "--output-last-message", answerPath,
        "-C", emptyDirectory,
        "-",
      ], `${request.systemPrompt}\n\n${request.userPrompt}`, request.workingDirectory);
      let finalJson: unknown;
      if (result.exitCode === 0) {
        try {
          finalJson = JSON.parse(await readFile(answerPath, "utf8"));
        } catch (error) {
          return {
            ...result,
            exitCode: 1,
            stderr: error instanceof Error ? error.message : String(error),
            finalJson: undefined,
            elapsedMs: performance.now() - startedAt,
          };
        }
      }
      return { ...result, finalJson, elapsedMs: performance.now() - startedAt };
    }

    const isRoute = request.systemPrompt.includes("ROUTE_ONLY");
    const result = await spawn([
      process.env.RESEARCH_EVAL_CLAUDE_BIN ?? "claude",
      "-p",
      "--safe-mode",
      "--no-session-persistence",
      "--permission-mode", "dontAsk",
      "--output-format stream-json",
      "--json-schema", JSON.stringify(request.schema),
      "--system-prompt", request.systemPrompt,
      "--tools", isRoute ? "" : "WebSearch,WebFetch",
      request.userPrompt,
    ], undefined, request.workingDirectory);
    let finalJson: unknown;
    if (result.exitCode === 0) {
      try {
        finalJson = parseClaudeResult(result.stdoutLines);
      } catch (error) {
        return {
          ...result,
          exitCode: 1,
          stderr: error instanceof Error ? error.message : String(error),
          finalJson: undefined,
          elapsedMs: performance.now() - startedAt,
        };
      }
    }
    return { ...result, finalJson, elapsedMs: performance.now() - startedAt };
  } finally {
    await rm(temporaryDirectory, { recursive: true, force: true });
  }
}
