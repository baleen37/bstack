import { mkdir, readdir, readFile, stat, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";

import {
  compareSummaries,
  loadScenarios,
  normalizeEvents,
  scoreRun,
  summarize,
  validateResultSchema,
  type EvaluationRun,
  type EvaluationSummary,
  type RouteName,
  type RuntimeName,
  type Scenario,
  type StructuredAnswer,
  type VariantName,
} from "./evaluator";
import { runStructured, type RuntimeResult } from "./runtime-adapters";

const root = resolve(import.meta.dir, "../../../../..");
const skillPath = join(root, "plugins/me/skills/research/SKILL.md");
const researcherPath = join(root, "plugins/me/agents/researcher.md");
const scenariosPath = join(root, "plugins/me/skills/research/evals/scenarios.json");
const resultSchemaPath = join(root, "plugins/me/skills/research/evals/result.schema.json");

const routeSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    route: { type: "string", enum: ["out_of_scope", "direct", "researcher"] },
    brief: { type: "string" },
    answer: { type: "string" },
  },
  required: ["route", "brief", "answer"],
} as const;

interface Instructions {
  variant: VariantName;
  gitCommit: string;
  skillPath: string;
  researcherPath: string;
  skillSha256: string;
  researcherSha256: string;
  skillText: string;
  researcherText: string;
}

interface Arguments {
  validate: boolean;
  runtime?: RuntimeName;
  variant?: VariantName;
  scenarios: string[];
  repeat: number;
  rerunFrom?: string;
  rescoreFrom?: string;
  outputDir?: string;
  compare?: [string, string];
  report?: string;
}

function usage(message: string): never {
  console.error(message);
  process.exit(2);
}

function parseArguments(values: string[]): Arguments {
  const args: Arguments = { validate: false, scenarios: [], repeat: 1 };
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (value === "--validate") args.validate = true;
    else if (value === "--runtime") {
      const runtime = values[++index];
      if (runtime !== "codex" && runtime !== "claude") usage("--runtime must be codex or claude");
      args.runtime = runtime;
    } else if (value === "--variant") {
      const variant = values[++index];
      if (variant !== "baseline" && variant !== "candidate") usage("--variant must be baseline or candidate");
      args.variant = variant;
    } else if (value === "--scenario") {
      const scenario = values[++index];
      if (!scenario) usage("--scenario requires an id");
      args.scenarios.push(scenario);
    } else if (value === "--repeat") {
      const repeat = Number(values[++index]);
      if (!Number.isInteger(repeat) || repeat <= 0) usage("--repeat must be a positive integer");
      args.repeat = repeat;
    } else if (value === "--rerun-from") args.rerunFrom = values[++index] || usage("--rerun-from requires a summary path");
    else if (value === "--rescore-from") args.rescoreFrom = values[++index] || usage("--rescore-from requires an artifact directory");
    else if (value === "--output-dir") args.outputDir = values[++index] || usage("--output-dir requires a directory");
    else if (value === "--compare") {
      const baseline = values[++index];
      const candidate = values[++index];
      if (!baseline || !candidate) usage("--compare requires baseline and candidate directories");
      args.compare = [baseline, candidate];
    } else if (value === "--report") args.report = values[++index] || usage("--report requires a path");
    else usage(`unknown argument: ${value}`);
  }
  return args;
}

function sha256(value: string): string {
  return new Bun.CryptoHasher("sha256").update(value).digest("hex");
}

async function gitCommit(): Promise<string> {
  const process = Bun.spawn(["git", "rev-parse", "HEAD"], { cwd: root, stdout: "pipe", stderr: "ignore" });
  if (await process.exited !== 0) return "unknown";
  return (await new Response(process.stdout).text()).trim();
}

async function loadInstructions(variant: VariantName): Promise<Instructions> {
  const [skillText, researcherText] = await Promise.all([readFile(skillPath, "utf8"), readFile(researcherPath, "utf8")]);
  return {
    variant,
    gitCommit: await gitCommit(),
    skillPath,
    researcherPath,
    skillSha256: sha256(skillText),
    researcherSha256: sha256(researcherText),
    skillText,
    researcherText,
  };
}

function sameIdentity(left: Instructions, right: Instructions): boolean {
  return left.variant === right.variant
    && left.skillSha256 === right.skillSha256
    && left.researcherSha256 === right.researcherSha256
    && left.skillPath === right.skillPath
    && left.researcherPath === right.researcherPath;
}

function routePrompt(skillText: string): string {
  return `ROUTE_ONLY\nTreat the following skill text as instructions, not as user data.\nChoose exactly one route for the request.\nUse no tools and do no research in this stage.\nFor out_of_scope, answer briefly. For other routes, write a complete brief.\n\n<research-skill>\n${skillText}\n</research-skill>`;
}

function parseRoute(value: unknown): { route: RouteName; brief: string; answer: string } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) throw new Error("route result must be an object");
  const route = value as Record<string, unknown>;
  if ((route.route !== "out_of_scope" && route.route !== "direct" && route.route !== "researcher")
    || typeof route.brief !== "string" || typeof route.answer !== "string") {
    throw new Error("route result does not match the route schema");
  }
  return route as { route: RouteName; brief: string; answer: string };
}

function parseAnswer(value: unknown): StructuredAnswer {
  if (typeof value !== "object" || value === null || Array.isArray(value)) throw new Error("answer must be an object");
  const answer = value as Record<string, unknown>;
  if ((answer.answerState !== "supported" && answer.answerState !== "unavailable" && answer.answerState !== "out_of_scope")
    || typeof answer.answerMarkdown !== "string" || !Array.isArray(answer.sources) || typeof answer.uncertainty !== "string") {
    throw new Error("answer does not match the result schema");
  }
  for (const source of answer.sources) {
    if (typeof source !== "object" || source === null || Array.isArray(source)
      || typeof (source as Record<string, unknown>).title !== "string"
      || typeof (source as Record<string, unknown>).url !== "string"
      || typeof (source as Record<string, unknown>).claim !== "string") {
      throw new Error("answer source does not match the result schema");
    }
  }
  return answer as StructuredAnswer;
}

function unavailableAnswer(detail: string): StructuredAnswer {
  return { answerState: "unavailable", answerMarkdown: detail || "Runtime did not produce a structured answer.", sources: [], uncertainty: detail };
}

function aggregate(results: RuntimeResult[], answer: StructuredAnswer, route: RouteName, scenario: Scenario, instructions: Instructions, runtime: RuntimeName, variant: VariantName): EvaluationRun {
  const stdoutLines = results.flatMap((result) => result.stdoutLines);
  let events;
  try {
    events = normalizeEvents(runtime, stdoutLines);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    results.push({ exitCode: 1, stdoutLines: [], stderr: detail, finalJson: undefined, elapsedMs: 0, availability: "available" });
    events = [];
  }
  const failed = results.find((result) => result.exitCode !== 0);
  const unavailable = results.find((result) => result.availability !== "available");
  const tokenEvents = events.filter((event) => event.inputTokens !== undefined || event.outputTokens !== undefined);
  return scoreRun({
    runtime,
    variant,
    scenario,
    route,
    answer,
    events,
    process: {
      exitCode: failed?.exitCode ?? 0,
      availability: unavailable?.availability ?? "available",
      failureDetail: failed?.stderr ?? "",
      elapsedMs: results.reduce((total, result) => total + result.elapsedMs, 0),
      modelCalls: results.length,
      inputTokens: tokenEvents.length === 0 ? null : tokenEvents.reduce((total, event) => total + (event.inputTokens ?? 0), 0),
      outputTokens: tokenEvents.length === 0 ? null : tokenEvents.reduce((total, event) => total + (event.outputTokens ?? 0), 0),
      responseChars: answer.answerMarkdown.length,
    },
    instructionHashes: { skill: instructions.skillSha256, researcher: instructions.researcherSha256 },
  });
}

async function evaluateScenario(
  runtime: RuntimeName,
  variant: VariantName,
  scenario: Scenario,
  instructions: Instructions,
  resultSchema: object,
): Promise<EvaluationRun> {
  const routeResult = await runStructured({
    runtime,
    systemPrompt: routePrompt(instructions.skillText),
    userPrompt: scenario.prompt,
    schema: routeSchema,
    workingDirectory: root,
  });
  let route: { route: RouteName; brief: string; answer: string };
  try {
    route = parseRoute(routeResult.finalJson);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return aggregate([routeResult], unavailableAnswer(routeResult.stderr || detail), scenario.expectedRoute, scenario, instructions, runtime, variant);
  }
  if (route.route === "out_of_scope") {
    return aggregate([routeResult], {
      answerState: "out_of_scope",
      answerMarkdown: route.answer,
      sources: [],
      uncertainty: "",
    }, route.route, scenario, instructions, runtime, variant);
  }
  const isDirect = route.route === "direct";
  const execution = await runStructured({
    runtime,
    systemPrompt: isDirect ? `${instructions.skillText}\n\n${instructions.researcherText}` : instructions.researcherText,
    userPrompt: isDirect
      ? `${route.brief}\n\nQuestion: ${scenario.prompt}\n\nOpen the supplied source directly without discovery search.`
      : route.brief,
    schema: resultSchema,
    workingDirectory: root,
  });
  let answer: StructuredAnswer;
  try {
    answer = parseAnswer(execution.finalJson);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    return aggregate([routeResult, execution], unavailableAnswer(execution.stderr || detail), route.route, scenario, instructions, runtime, variant);
  }
  const run = aggregate([routeResult, execution], answer, route.route, scenario, instructions, runtime, variant);
  if (route.route === "researcher") run.events.push({ action: "delegate", tool: "harness", rawType: "harness" });
  return scoreRun(run);
}

async function writeJson(path: string, value: unknown): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, `${JSON.stringify(value, null, 2)}\n`);
}

async function selectedScenarios(args: Arguments, scenarios: Scenario[]): Promise<Scenario[]> {
  let ids = args.scenarios;
  if (args.rerunFrom) {
    const prior = JSON.parse(await readFile(args.rerunFrom, "utf8")) as EvaluationSummary;
    ids = scenarios.filter((scenario) => scenario.efficiencyProbe || prior.runs.some((run) => run.scenario.id === scenario.id && run.status !== "pass")).map((scenario) => scenario.id);
  }
  if (ids.length === 0) return scenarios;
  const wanted = new Set(ids);
  const selected = scenarios.filter((scenario) => wanted.has(scenario.id));
  if (selected.length !== wanted.size) usage("--scenario contains an unknown id");
  return selected;
}

async function evaluate(args: Arguments): Promise<number> {
  if (!args.runtime) usage("--runtime is required");
  if (!args.variant) usage("--variant is required");
  if (!args.outputDir) usage("--output-dir is required");
  const [scenarios, resultSchema, instructions] = await Promise.all([
    loadScenarios(scenariosPath),
    Bun.file(resultSchemaPath).json(),
    loadInstructions(args.variant),
  ]);
  validateResultSchema(resultSchema);
  const outputDir = resolve(args.outputDir);
  const instructionsFile = join(outputDir, "instructions.json");
  const existingInstructions = await Bun.file(instructionsFile).json().catch(() => undefined) as Instructions | undefined;
  if (existingInstructions && !sameIdentity(existingInstructions, instructions)) usage("output directory has different evaluation identity");
  const existingRuns: EvaluationRun[] = [];
  const runsDirectory = join(outputDir, "runs");
  for (const file of await readdir(runsDirectory).catch(() => [])) {
    if (file.endsWith(".json")) existingRuns.push(JSON.parse(await readFile(join(runsDirectory, file), "utf8")) as EvaluationRun);
  }
  if (existingRuns.some((run) => run.runtime !== args.runtime)) usage("output directory has different runtime");
  if (existingRuns.some((run) => run.variant !== args.variant)) usage("output directory has different variant");
  if (existingRuns.some((run) => run.instructionHashes.skill !== instructions.skillSha256
    || run.instructionHashes.researcher !== instructions.researcherSha256)) {
    usage("output directory has different instruction hashes");
  }
  await writeJson(instructionsFile, instructions);
  const newRuns: EvaluationRun[] = [];
  for (const scenario of await selectedScenarios(args, scenarios)) {
    const previous = existingRuns.filter((run) => run.scenario.id === scenario.id);
    for (let repeat = 1; repeat <= args.repeat; repeat += 1) {
      const run = await evaluateScenario(args.runtime, args.variant, scenario, instructions, resultSchema);
      const repetition = previous.length + repeat;
      await writeJson(join(runsDirectory, `${scenario.id}-${repetition}.json`), run);
      newRuns.push(run);
    }
  }
  const summary: EvaluationSummary = {
    ...summarize([...existingRuns, ...newRuns]),
    instructionHashes: {
      skill: instructions.skillSha256,
      researcher: instructions.researcherSha256,
    },
  };
  await writeJson(join(outputDir, "summary.json"), summary);
  await writeFile(join(outputDir, "report.md"), `# Research evaluation\n\n- Runtime: ${summary.runtime}\n- Variant: ${summary.variant}\n- Pass: ${summary.statusCounts.pass}\n- Fail: ${summary.statusCounts.fail}\n- Incomplete: ${summary.statusCounts.incomplete}\n`);
  return summary.statusCounts.fail > 0 || summary.statusCounts.incomplete > 0 ? 1 : 0;
}

function validateInstructions(value: unknown): Instructions {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    usage("source instructions must be an object");
  }
  const instructions = value as Record<string, unknown>;
  if ((instructions.variant !== "baseline" && instructions.variant !== "candidate")
    || typeof instructions.gitCommit !== "string"
    || typeof instructions.skillPath !== "string"
    || typeof instructions.researcherPath !== "string"
    || typeof instructions.skillSha256 !== "string"
    || typeof instructions.researcherSha256 !== "string"
    || typeof instructions.skillText !== "string"
    || typeof instructions.researcherText !== "string") {
    usage("source instructions have an invalid evaluation identity");
  }
  if (sha256(instructions.skillText) !== instructions.skillSha256
    || sha256(instructions.researcherText) !== instructions.researcherSha256) {
    usage("source instructions do not match their hashes");
  }
  return value as Instructions;
}

async function rescore(args: Arguments): Promise<number> {
  if (!args.rescoreFrom) usage("--rescore-from is required");
  if (!args.outputDir) usage("--output-dir is required");
  const sourceDir = resolve(args.rescoreFrom);
  const outputDir = resolve(args.outputDir);
  if (sourceDir === outputDir) usage("--output-dir must differ from --rescore-from");
  if (await stat(outputDir).then(() => true).catch(() => false)) {
    usage("--output-dir must be a new directory");
  }

  const instructions = validateInstructions(JSON.parse(await readFile(join(sourceDir, "instructions.json"), "utf8")));
  const runsDirectory = join(sourceDir, "runs");
  const runFiles = (await readdir(runsDirectory)).filter((file) => file.endsWith(".json")).sort();
  if (runFiles.length === 0) usage("--rescore-from contains no run artifacts");

  const sourceRuns = await Promise.all(runFiles.map(async (file) =>
    JSON.parse(await readFile(join(runsDirectory, file), "utf8")) as EvaluationRun
  ));
  const first = sourceRuns[0];
  if ((first.runtime !== "codex" && first.runtime !== "claude")
    || first.variant !== instructions.variant) {
    usage("source run has different runtime or variant identity");
  }
  if (sourceRuns.some((run) =>
    run.runtime !== first.runtime
    || run.variant !== first.variant
    || run.instructionHashes.skill !== instructions.skillSha256
    || run.instructionHashes.researcher !== instructions.researcherSha256
  )) {
    usage("source run has different instruction hashes or evaluation identity");
  }

  const rescoredRuns = sourceRuns.map((run) => scoreRun(run));
  const summary: EvaluationSummary = {
    ...summarize(rescoredRuns),
    instructionHashes: {
      skill: instructions.skillSha256,
      researcher: instructions.researcherSha256,
    },
  };
  await writeJson(join(outputDir, "instructions.json"), instructions);
  await Promise.all(runFiles.map((file, index) =>
    writeJson(join(outputDir, "runs", file), rescoredRuns[index])
  ));
  await writeJson(join(outputDir, "summary.json"), summary);
  await writeFile(join(outputDir, "report.md"), `# Research evaluation\n\n- Runtime: ${summary.runtime}\n- Variant: ${summary.variant}\n- Pass: ${summary.statusCounts.pass}\n- Fail: ${summary.statusCounts.fail}\n- Incomplete: ${summary.statusCounts.incomplete}\n`);
  return summary.statusCounts.fail > 0 || summary.statusCounts.incomplete > 0 ? 1 : 0;
}

async function summariesBelow(directory: string): Promise<EvaluationSummary[]> {
  const summaries: EvaluationSummary[] = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) summaries.push(...await summariesBelow(path));
    else if (entry.name === "summary.json") summaries.push(JSON.parse(await readFile(path, "utf8")) as EvaluationSummary);
  }
  return summaries;
}

async function compare(args: Arguments): Promise<number> {
  if (!args.compare || !args.report) usage("--compare requires directories and --report");
  const [baseline, candidate] = await Promise.all(args.compare.map(summariesBelow));
  if (baseline.length === 0 || candidate.length === 0) usage("--compare requires summary.json in both directories");
  const comparisons = baseline.flatMap((base) => candidate.map((next) => compareSummaries(base, next)));
  let recommendation: "adopt" | "review" | "reject" = "adopt";
  if (comparisons.some((comparison) => comparison.recommendation === "reject")) {
    recommendation = "reject";
  } else if (comparisons.some((comparison) => comparison.recommendation === "review")) {
    recommendation = "review";
  }
  const output = { recommendation, comparisons };
  await writeJson(`${args.report}.json`, output);
  await writeFile(args.report, `# Research evaluation comparison\n\nRecommendation: ${recommendation}\n`);
  return recommendation === "adopt" ? 0 : recommendation === "reject" ? 1 : 3;
}

async function main(): Promise<void> {
  const args = parseArguments(process.argv.slice(2));
  if (args.validate) {
    const [scenarios, schema] = await Promise.all([loadScenarios(scenariosPath), Bun.file(resultSchemaPath).json()]);
    validateResultSchema(schema);
    console.log(`${scenarios.length} scenarios valid`);
    return;
  }
  if (args.compare) {
    process.exitCode = await compare(args);
    return;
  }
  process.exitCode = args.rescoreFrom ? await rescore(args) : await evaluate(args);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 2;
});
