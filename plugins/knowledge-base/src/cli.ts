#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import {
  parseArgs,
  type ParseArgsOptionsConfig,
} from "node:util";
import { fileURLToPath } from "node:url";
import { isAbsolute, resolve } from "node:path";
import { createServices, type KnowledgeBaseServices } from "./services.js";
import { isScope, type Scope } from "./types.js";

const HELP = `Usage: knowledge-base <command> [options]

Commands:
  setup --repo <owner/repo> [--path <absolute-path>]
  sync
  index [--scope personal|wooto|all] [--force]
  search <query> [--scope personal|wooto|all] [--limit 1..50] [--json]
  get <ref> [--from-line >=1] [--max-lines 1..1000]
  status [--json]
  mcp
`;

export interface CliIo {
  stdout(text: string): void;
  stderr(text: string): void;
}

class UsageError extends Error {}

type Parsed<T extends ParseArgsOptionsConfig> = {
  positionals: string[];
  values: {
    [Key in keyof T]?: T[Key]["type"] extends "boolean" ? boolean : string;
  };
};

export async function runCli(
  argv: readonly string[],
  services: KnowledgeBaseServices,
  io: CliIo,
): Promise<number> {
  try {
    if (argv.length === 1 && argv[0] === "--version") {
      io.stdout(`${await packageVersion()}\n`);
      return 0;
    }
    if (argv.length === 1 && argv[0] === "--help") {
      io.stdout(HELP);
      return 0;
    }

    const [command, ...args] = argv;
    if (command === undefined) {
      throw new UsageError("a command is required");
    }

    switch (command) {
      case "setup":
        return await runSetup(args, services, io);
      case "sync":
        return await runSync(args, services, io);
      case "index":
        return await runIndex(args, services, io);
      case "search":
        return await runSearch(args, services, io);
      case "get":
        return await runGet(args, services, io);
      case "status":
        return await runStatus(args, services, io);
      case "mcp":
        return await runMcp(args, services);
      default:
        throw new UsageError(`unknown command: ${command}`);
    }
  } catch (error) {
    io.stderr(`${message(error)}\n`);
    return error instanceof UsageError ? 2 : 1;
  }
}

async function runSetup(
  args: readonly string[],
  services: KnowledgeBaseServices,
  io: CliIo,
): Promise<number> {
  const parsed = parse(args, {
    repo: { type: "string" },
    path: { type: "string" },
  });
  noPositionals(parsed.positionals);
  const repository = parsed.values.repo;
  if (repository === undefined) {
    throw new UsageError("--repo <owner/repo> is required");
  }
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repository)) {
    throw new UsageError("--repo must use owner/repo form");
  }
  if (parsed.values.path !== undefined && !isAbsolute(parsed.values.path)) {
    throw new UsageError("--path must be an absolute path");
  }
  const config = await services.setup({ repository, path: parsed.values.path });
  io.stdout(`Configured ${config.repository}\n`);
  return 0;
}

async function runSync(
  args: readonly string[],
  services: KnowledgeBaseServices,
  io: CliIo,
): Promise<number> {
  noPositionals(parse(args, {}).positionals);
  await services.pull();
  await services.index("all", false);
  io.stdout("Synchronized and indexed knowledge base.\n");
  return 0;
}

async function runIndex(
  args: readonly string[],
  services: KnowledgeBaseServices,
  io: CliIo,
): Promise<number> {
  const parsed = parse(args, {
    scope: { type: "string" },
    force: { type: "boolean" },
  });
  noPositionals(parsed.positionals);
  await services.index(scope(parsed.values.scope), parsed.values.force ?? false);
  io.stdout("Indexed knowledge base.\n");
  return 0;
}

async function runSearch(
  args: readonly string[],
  services: KnowledgeBaseServices,
  io: CliIo,
): Promise<number> {
  const parsed = parse(args, {
    scope: { type: "string" },
    limit: { type: "string" },
    json: { type: "boolean" },
  });
  const query = exactlyOne(parsed.positionals, "<query> is required");
  const results = await services.search(query, scope(parsed.values.scope), limit(parsed.values.limit));
  io.stdout(parsed.values.json ? json(results) : formatSearchResults(results));
  return 0;
}

async function runGet(
  args: readonly string[],
  services: KnowledgeBaseServices,
  io: CliIo,
): Promise<number> {
  const parsed = parse(args, {
    "from-line": { type: "string" },
    "max-lines": { type: "string" },
  });
  const ref = exactlyOne(parsed.positionals, "<ref> is required");
  const result = await services.get(
    ref,
    integer(parsed.values["from-line"], "--from-line must be an integer of at least 1", 1),
    integer(parsed.values["max-lines"], "--max-lines must be an integer from 1 to 1000", 1, 1000),
  );
  io.stdout(formatGetResult(result));
  return 0;
}

async function runStatus(
  args: readonly string[],
  services: KnowledgeBaseServices,
  io: CliIo,
): Promise<number> {
  const parsed = parse(args, { json: { type: "boolean" } });
  noPositionals(parsed.positionals);
  const result = await services.status();
  io.stdout(parsed.values.json ? json(result) : `${JSON.stringify(result, null, 2)}\n`);
  return 0;
}

async function runMcp(args: readonly string[], services: KnowledgeBaseServices): Promise<number> {
  noPositionals(parse(args, {}).positionals);
  await services.startMcp();
  return 0;
}

function parse<T extends ParseArgsOptionsConfig>(
  args: readonly string[],
  options: T,
): Parsed<T> {
  try {
    return parseArgs({ args, options, allowPositionals: true, strict: true }) as Parsed<T>;
  } catch (error) {
    throw new UsageError(message(error));
  }
}

function noPositionals(positionals: readonly string[]): void {
  if (positionals.length > 0) {
    throw new UsageError(`unexpected argument: ${positionals[0]}`);
  }
}

function exactlyOne(positionals: readonly string[], requiredMessage: string): string {
  if (positionals.length === 0) {
    throw new UsageError(requiredMessage);
  }
  if (positionals.length > 1) {
    throw new UsageError(`unexpected argument: ${positionals[1]}`);
  }
  return positionals[0] as string;
}

function scope(value: string | undefined): Scope {
  if (value === undefined) {
    return "all";
  }
  if (!isScope(value)) {
    throw new UsageError("--scope must be personal, wooto, or all");
  }
  return value;
}

function limit(value: string | undefined): number {
  return integer(value, "--limit must be an integer from 1 to 50", 1, 50) ?? 10;
}

function integer(
  value: string | undefined,
  invalidMessage: string,
  minimum: number,
  maximum?: number,
): number | undefined {
  if (value === undefined) {
    return undefined;
  }
  const number = Number(value);
  if (!Number.isInteger(number) || number < minimum || (maximum !== undefined && number > maximum)) {
    throw new UsageError(invalidMessage);
  }
  return number;
}

function formatSearchResults(results: readonly unknown[]): string {
  return results.map((result) => JSON.stringify(result)).join("\n") + (results.length > 0 ? "\n" : "");
}

function formatGetResult(result: unknown): string {
  if (typeof result === "object" && result !== null && "title" in result && "body" in result) {
    const { title, body } = result as { title: unknown; body: unknown };
    return `${String(title)}\n\n${String(body)}\n`;
  }
  return `${JSON.stringify(result, null, 2)}\n`;
}

function json(value: unknown): string {
  return `${JSON.stringify(value)}\n`;
}

async function packageVersion(): Promise<string> {
  const packageJson = JSON.parse(
    await readFile(new URL("../package.json", import.meta.url), "utf8"),
  ) as { version?: unknown };
  if (typeof packageJson.version !== "string") {
    throw new Error("package version is unavailable");
  }
  return packageJson.version;
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

export function assertSupportedNodeVersion(version = process.versions.node): void {
  const major = Number(version.split(".")[0]);
  if (!Number.isInteger(major) || major < 22) {
    throw new Error("knowledge-base requires Node.js >=22");
  }
}

if (process.argv[1] !== undefined && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  try {
    assertSupportedNodeVersion();
    process.exitCode = await runCli(process.argv.slice(2), createServices(), {
      stdout: (text) => process.stdout.write(text),
      stderr: (text) => process.stderr.write(text),
    });
  } catch (error) {
    process.stderr.write(`${message(error)}\n`);
    process.exitCode = 1;
  }
}
