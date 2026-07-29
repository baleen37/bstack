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

const schemaMapKeywords = new Set([
  "properties",
  "$defs",
  "definitions",
  "patternProperties",
  "dependentSchemas",
]);
const schemaArrayKeywords = new Set(["allOf", "anyOf", "oneOf", "prefixItems"]);
const schemaValueKeywords = new Set([
  "additionalItems",
  "additionalProperties",
  "contains",
  "contentSchema",
  "else",
  "if",
  "not",
  "propertyNames",
  "then",
  "unevaluatedItems",
  "unevaluatedProperties",
]);

function sanitizeSchemaMap(value: unknown): unknown {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return value;
  return Object.fromEntries(
    Object.entries(value).map(([name, schema]) => [name, sanitizeCodexSchema(schema)]),
  );
}

function sanitizeDependencies(value: unknown): unknown {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return value;
  return Object.fromEntries(Object.entries(value).map(([name, dependency]) => [
    name,
    Array.isArray(dependency) ? dependency : sanitizeCodexSchema(dependency),
  ]));
}

function sanitizeCodexSchema(value: unknown): unknown {
  if (Array.isArray(value)) return value;
  if (typeof value !== "object" || value === null) return value;
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => key !== "$schema" && key !== "format" && key !== "minLength")
    .map(([key, entry]) => {
      if (schemaMapKeywords.has(key)) return [key, sanitizeSchemaMap(entry)];
      if (schemaArrayKeywords.has(key) && Array.isArray(entry)) {
        return [key, entry.map((schema) => sanitizeCodexSchema(schema))];
      }
      if (key === "items") {
        const items = Array.isArray(entry)
          ? entry.map((schema) => sanitizeCodexSchema(schema))
          : sanitizeCodexSchema(entry);
        return [key, items];
      }
      if (key === "dependencies") return [key, sanitizeDependencies(entry)];
      if (schemaValueKeywords.has(key)) {
        return [key, sanitizeCodexSchema(entry)];
      }
      return [key, entry];
    }));
}

function runtimeErrorMessage(stdoutLines: string[]): string {
  for (const line of stdoutLines) {
    try {
      const value = JSON.parse(line) as Record<string, unknown>;
      if (value.type !== "error" && value.type !== "turn.failed") continue;
      if (typeof value.message === "string") return value.message;
      if (typeof value.error === "string") return value.error;
      if (typeof value.error === "object" && value.error !== null
        && typeof (value.error as Record<string, unknown>).message === "string") {
        return (value.error as Record<string, string>).message;
      }
    } catch {
      continue;
    }
  }
  return "";
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
    const stdoutLines = lines(stdout);
    const failureDetail = stderr.trim() === "" && exitCode !== 0 ? runtimeErrorMessage(stdoutLines) : stderr;
    return {
      exitCode,
      stdoutLines,
      stderr: failureDetail,
      availability: availabilityFor(exitCode, failureDetail),
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
        writeFile(schemaPath, JSON.stringify(sanitizeCodexSchema(request.schema))),
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
      "--output-format", "stream-json",
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
