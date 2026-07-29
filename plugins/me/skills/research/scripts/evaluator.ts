export type RuntimeName = "codex" | "claude";
export type VariantName = "baseline" | "candidate";
export type RouteName = "out_of_scope" | "direct" | "researcher";
export type RunStatus = "pass" | "fail" | "incomplete";
export type ActionName = "search" | "open" | "delegate" | "other";

export interface Scenario {
  id: string;
  prompt: string;
  asOf: string | null;
  status: "active" | "stale";
  staleReason: string | null;
  expectedRoute: RouteName;
  expectedAnswerStates: Array<"supported" | "unavailable" | "out_of_scope">;
  requiredPatterns: string[];
  requiredDomains: string[];
  minSources: number;
  maxSources: number;
  requireOpen: boolean;
  maxSearches: number | null;
  minDelegations: number;
  maxDelegations: number;
  forbiddenActions: Array<"search" | "open" | "delegate">;
  requireUncertainty: boolean;
  efficiencyProbe: boolean;
}

export interface StructuredAnswer {
  answerState: "supported" | "unavailable" | "out_of_scope";
  answerMarkdown: string;
  sources: Array<{ title: string; url: string; claim: string }>;
  uncertainty: string;
}

export interface NormalizedEvent {
  action: ActionName;
  tool?: string;
  url?: string;
  inputTokens?: number;
  outputTokens?: number;
  rawType: string;
}

export interface Assertion {
  name: string;
  status: RunStatus;
  detail: string;
}

export interface ProcessMetrics {
  exitCode: number;
  availability: "available" | "missing_cli" | "auth_unavailable";
  failureDetail: string;
  elapsedMs: number;
  modelCalls: number;
  inputTokens: number | null;
  outputTokens: number | null;
  responseChars: number;
}

export interface ScoreInput {
  runtime: RuntimeName;
  variant: VariantName;
  scenario: Scenario;
  route: RouteName;
  answer: StructuredAnswer;
  events: NormalizedEvent[];
  process: ProcessMetrics;
  instructionHashes: { skill: string; researcher: string };
}

export interface EvaluationRun extends ScoreInput {
  status: RunStatus;
  assertions: Assertion[];
}

export interface EfficiencyMedian {
  modelCalls: number;
  inputTokens: number | null;
  outputTokens: number | null;
  responseChars: number;
  elapsedMs: number;
}

export interface EvaluationSummary {
  runtime: RuntimeName;
  variant: VariantName;
  instructionHashes?: { skill: string; researcher: string };
  runs: EvaluationRun[];
  statusCounts: Record<RunStatus, number>;
  failedScenarios: string[];
  incompleteScenarios: string[];
  staleScenarios: string[];
  efficiencyMedians: Record<string, EfficiencyMedian>;
}

export interface Comparison {
  qualityGate: "pass" | "fail" | "incomplete";
  efficiencyDecision: "improved" | "mixed" | "unavailable";
  recommendation: "adopt" | "review" | "reject";
  scenarioChanges: Array<{
    runtime: RuntimeName;
    scenarioId: string;
    baseline: RunStatus;
    candidate: RunStatus;
  }>;
}

type JsonObject = Record<string, unknown>;

const scenarioKeys = [
  "id",
  "prompt",
  "asOf",
  "status",
  "staleReason",
  "expectedRoute",
  "expectedAnswerStates",
  "requiredPatterns",
  "requiredDomains",
  "minSources",
  "maxSources",
  "requireOpen",
  "maxSearches",
  "minDelegations",
  "maxDelegations",
  "forbiddenActions",
  "requireUncertainty",
  "efficiencyProbe",
] as const;

const answerStates = ["supported", "unavailable", "out_of_scope"] as const;
const routes = ["out_of_scope", "direct", "researcher"] as const;
const actions = ["search", "open", "delegate"] as const;

function isObject(value: unknown): value is JsonObject {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function fail(path: string, message: string): never {
  throw new Error(`${path} ${message}`);
}

function requireObject(value: unknown, path: string): JsonObject {
  if (!isObject(value)) fail(path, "must be an object");
  return value;
}

function requireString(value: unknown, path: string, nonEmpty = false): string {
  if (typeof value !== "string" || (nonEmpty && value.trim() === "")) {
    fail(path, nonEmpty ? "must be a non-empty string" : "must be a string");
  }
  return value;
}

function requireBoolean(value: unknown, path: string): boolean {
  if (typeof value !== "boolean") fail(path, "must be a boolean");
  return value;
}

function requireNonNegativeInteger(value: unknown, path: string): number {
  if (!Number.isInteger(value) || typeof value !== "number" || value < 0) {
    fail(path, "must be a non-negative integer");
  }
  return value;
}

function requireStringArray(value: unknown, path: string): string[] {
  if (!Array.isArray(value)) fail(path, "must be an array");
  return value.map((entry, index) => requireString(entry, `${path}[${index}]`));
}

function hasOnlyKeys(value: JsonObject, allowed: readonly string[], path: string): void {
  for (const key of Object.keys(value)) {
    if (!allowed.includes(key)) fail(`${path}.${key}`, "is not allowed");
  }
}

function isDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(date.valueOf()) && date.toISOString().slice(0, 10) === value;
}

export function validateScenarios(value: unknown): asserts value is Scenario[] {
  if (!Array.isArray(value)) fail("scenarios", "must be an array");
  const ids = new Set<string>();

  value.forEach((entry, index) => {
    const path = `scenarios[${index}]`;
    const scenario = requireObject(entry, path);
    hasOnlyKeys(scenario, scenarioKeys, path);

    const id = requireString(scenario.id, `${path}.id`, true);
    if (ids.has(id)) fail(`${path}.id`, `duplicates ${id}`);
    ids.add(id);
    requireString(scenario.prompt, `${path}.prompt`, true);

    if (scenario.asOf !== null) {
      const asOf = requireString(scenario.asOf, `${path}.asOf`);
      if (!isDate(asOf)) fail(`${path}.asOf`, "must be an ISO date or null");
    }

    if (scenario.status !== "active" && scenario.status !== "stale") {
      fail(`${path}.status`, "must be active or stale");
    }
    if (scenario.status === "stale") {
      requireString(scenario.staleReason, `${path}.staleReason`, true);
    } else if (scenario.staleReason !== null) {
      fail(`${path}.staleReason`, "must be null for an active scenario");
    }

    if (!routes.includes(scenario.expectedRoute as RouteName)) {
      fail(`${path}.expectedRoute`, "must be out_of_scope, direct, or researcher");
    }
    const states = requireStringArray(scenario.expectedAnswerStates, `${path}.expectedAnswerStates`);
    if (states.length === 0 || states.some((state) => !answerStates.includes(state as StructuredAnswer["answerState"]))) {
      fail(`${path}.expectedAnswerStates`, "must contain supported, unavailable, or out_of_scope values");
    }

    const patterns = requireStringArray(scenario.requiredPatterns, `${path}.requiredPatterns`);
    patterns.forEach((pattern, patternIndex) => {
      try {
        new RegExp(pattern, "i");
      } catch {
        fail(`${path}.requiredPatterns[${patternIndex}]`, "must be a valid regular expression");
      }
    });
    requireStringArray(scenario.requiredDomains, `${path}.requiredDomains`).forEach((domain, domainIndex) => {
      if (domain !== domain.toLowerCase()) {
        fail(`${path}.requiredDomains[${domainIndex}]`, "must be lowercase");
      }
    });

    const minSources = requireNonNegativeInteger(scenario.minSources, `${path}.minSources`);
    const maxSources = requireNonNegativeInteger(scenario.maxSources, `${path}.maxSources`);
    if (minSources > maxSources) fail(path, "minSources must not exceed maxSources");
    requireBoolean(scenario.requireOpen, `${path}.requireOpen`);
    if (scenario.maxSearches !== null) {
      requireNonNegativeInteger(scenario.maxSearches, `${path}.maxSearches`);
    }
    const minDelegations = requireNonNegativeInteger(scenario.minDelegations, `${path}.minDelegations`);
    const maxDelegations = requireNonNegativeInteger(scenario.maxDelegations, `${path}.maxDelegations`);
    if (minDelegations > maxDelegations) fail(path, "minDelegations must not exceed maxDelegations");
    const forbidden = requireStringArray(scenario.forbiddenActions, `${path}.forbiddenActions`);
    if (forbidden.some((action) => !actions.includes(action as (typeof actions)[number]))) {
      fail(`${path}.forbiddenActions`, "must contain search, open, or delegate values");
    }
    requireBoolean(scenario.requireUncertainty, `${path}.requireUncertainty`);
    requireBoolean(scenario.efficiencyProbe, `${path}.efficiencyProbe`);
  });
}

export async function loadScenarios(path: string): Promise<Scenario[]> {
  const value = await Bun.file(path).json();
  validateScenarios(value);
  return value;
}

export function validateResultSchema(value: unknown): asserts value is object {
  const schema = requireObject(value, "resultSchema");
  const topProperties = requireObject(schema.properties, "resultSchema.properties");
  const expectedTopKeys = ["answerState", "answerMarkdown", "sources", "uncertainty"];
  const required = schema.required;

  if (schema.type !== "object") fail("resultSchema.type", "must be object");
  if (schema.additionalProperties !== false) fail("resultSchema.additionalProperties", "must be false");
  if (!Array.isArray(required) || expectedTopKeys.some((key) => !required.includes(key))) {
    fail("resultSchema.required", "must contain the four answer fields");
  }
  expectedTopKeys.forEach((key) => {
    if (!(key in topProperties)) fail(`resultSchema.properties.${key}`, "is required");
  });

  const answerState = requireObject(topProperties.answerState, "resultSchema.properties.answerState");
  if (answerState.type !== "string") fail("resultSchema.properties.answerState.type", "must be string");
  if (!Array.isArray(answerState.enum) || answerStates.some((state) => !answerState.enum?.includes(state))) {
    fail("resultSchema.properties.answerState.enum", "must contain supported, unavailable, and out_of_scope");
  }
  const answerMarkdown = requireObject(topProperties.answerMarkdown, "resultSchema.properties.answerMarkdown");
  if (answerMarkdown.type !== "string") fail("resultSchema.properties.answerMarkdown.type", "must be string");
  const uncertainty = requireObject(topProperties.uncertainty, "resultSchema.properties.uncertainty");
  if (uncertainty.type !== "string") fail("resultSchema.properties.uncertainty.type", "must be string");

  const sources = requireObject(topProperties.sources, "resultSchema.properties.sources");
  if (sources.type !== "array") fail("resultSchema.properties.sources.type", "must be array");
  const source = requireObject(sources.items, "resultSchema.properties.sources.items");
  const sourceProperties = requireObject(source.properties, "resultSchema.properties.sources.items.properties");
  if (source.type !== "object") fail("resultSchema.properties.sources.items.type", "must be object");
  if (source.additionalProperties !== false) fail("resultSchema.properties.sources.items.additionalProperties", "must be false");
  if (!Array.isArray(source.required) || ["title", "url", "claim"].some((key) => !source.required.includes(key))) {
    fail("resultSchema.properties.sources.items.required", "must contain title, url, and claim");
  }
  ["title", "url", "claim"].forEach((key) => {
    const property = requireObject(sourceProperties[key], `resultSchema.properties.sources.items.properties.${key}`);
    if (property.type !== "string") fail(`resultSchema.properties.sources.items.properties.${key}.type`, "must be string");
  });
}

function isInvocationRecord(rawType: string): boolean {
  return /(?:tool_use|tool_call|function_call)$/.test(rawType);
}

function isDelegationTool(tool: string): boolean {
  const name = tool.toLowerCase().split(/__|[.:/]/).at(-1);
  return name === "spawn_agent" || name === "agent" || name === "task" || name === "delegate";
}

function actionFor(tool: string, invocationRecord: boolean): ActionName {
  const name = tool.toLowerCase();
  if (name.includes("search")) return "search";
  if (name.includes("open") || name.includes("fetch") || name.includes("read_url")) return "open";
  if (invocationRecord && isDelegationTool(tool)) return "delegate";
  return "other";
}

function firstUrl(value: unknown): string | undefined {
  if (typeof value === "string") return value.match(/https?:\/\/[^\s"')\]}>,]+/i)?.[0];
  if (Array.isArray(value)) {
    for (const entry of value) {
      const url = firstUrl(entry);
      if (url) return url;
    }
    return undefined;
  }
  if (!isObject(value)) return undefined;
  for (const key of ["url", "ref_id", "href"]) {
    if (typeof value[key] === "string" && /^https?:\/\//i.test(value[key])) return value[key];
  }
  for (const entry of Object.values(value)) {
    const url = firstUrl(entry);
    if (url) return url;
  }
  return undefined;
}

function tokenValue(value: JsonObject, snake: string, camel: string): number | undefined {
  const token = value[snake] ?? value[camel];
  return typeof token === "number" ? token : undefined;
}

export function normalizeEvents(runtime: RuntimeName, lines: string[]): NormalizedEvent[] {
  const events: NormalizedEvent[] = [];

  const visit = (value: unknown, inheritedType: string): void => {
    if (Array.isArray(value)) {
      value.forEach((entry) => visit(entry, inheritedType));
      return;
    }
    if (!isObject(value)) return;

    const ownType = typeof value.type === "string" ? value.type : undefined;
    const rawType = ownType ?? inheritedType;
    const command = typeof value.command === "string" ? value.command : typeof value.cmd === "string" ? value.cmd : "";
    const namedTool = typeof value.tool === "string"
      ? value.tool
      : typeof value.name === "string"
        ? value.name
        : typeof value.type === "string"
          ? value.type
          : "";
    const commandOpensUrl = /\b(curl|wget)\b/i.test(command) && Boolean(firstUrl(command));
    const assistantOutput = runtime === "codex" && rawType === "agent_message";
    const invocationRecord = ownType !== undefined && isInvocationRecord(ownType);
    const action = assistantOutput ? "other" : commandOpensUrl ? "open" : actionFor(namedTool, invocationRecord);
    if (action !== "other" || assistantOutput) {
      events.push({ action, tool: namedTool || undefined, url: firstUrl(value), rawType });
    }

    Object.values(value).forEach((entry) => visit(entry, rawType));

    const inputTokens = tokenValue(value, "input_tokens", "inputTokens");
    const outputTokens = tokenValue(value, "output_tokens", "outputTokens");
    if (inputTokens !== undefined || outputTokens !== undefined) {
      events.push({ action: "other", inputTokens, outputTokens, rawType });
    }
  };

  lines.forEach((line, index) => {
    if (line.trim() === "") return;
    try {
      visit(JSON.parse(line), "unknown");
    } catch (error) {
      if (error instanceof SyntaxError) throw new Error(`event line ${index + 1} is not valid JSON`);
      throw error;
    }
  });
  return events;
}

function normalizeUrl(value: string): string {
  try {
    const url = new URL(value);
    url.hash = "";
    url.hostname = url.hostname.replace(/^www\./i, "");
    const path = url.pathname.length > 1 ? url.pathname.replace(/\/$/, "") : url.pathname;
    return `${url.protocol}//${url.host}${path}${url.search}`;
  } catch {
    return value.replace(/#.*$/, "").replace(/\/$/, "").replace(/:\/\/www\./i, "://");
  }
}

function hostFor(url: string): string | undefined {
  try {
    return new URL(url).hostname.replace(/^www\./i, "").toLowerCase();
  } catch {
    return undefined;
  }
}

function assertion(name: string, passed: boolean, detail: string, incomplete = false): Assertion {
  return { name, status: passed ? "pass" : incomplete ? "incomplete" : "fail", detail };
}

function answerParagraphContainsSource(answer: string, source: StructuredAnswer["sources"][number]): boolean {
  const words = source.claim.match(/[\p{L}\p{N}]{4,}/gu) ?? [];
  return answer.split(/\n\s*\n/).some((paragraph) =>
    paragraph.includes(source.url) && words.some((word) => new RegExp(word.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i").test(paragraph)),
  );
}

export function scoreRun(input: ScoreInput): EvaluationRun {
  const assertions: Assertion[] = [];
  const { scenario, answer, events, process } = input;

  const processAvailable = process.availability === "available";
  assertions.push(assertion(
    "process_exit",
    process.exitCode === 0,
    process.exitCode === 0 ? "process exited successfully" : process.failureDetail || `exit code ${process.exitCode}`,
    !processAvailable,
  ));
  assertions.push(assertion("route", input.route === scenario.expectedRoute, `expected ${scenario.expectedRoute}, received ${input.route}`));
  assertions.push(assertion(
    "answer_state",
    scenario.expectedAnswerStates.includes(answer.answerState) && answer.answerMarkdown.trim() !== "",
    "answer state and answer markdown must match the scenario",
  ));
  assertions.push(assertion(
    "required_patterns",
    scenario.requiredPatterns.every((pattern) => new RegExp(pattern, "i").test(answer.answerMarkdown)),
    "answer markdown must satisfy every required pattern",
  ));

  const hosts = answer.sources.map((source) => hostFor(source.url));
  const uniqueHosts = new Set(hosts.filter((host): host is string => Boolean(host)));
  const requiredHosts = scenario.requiredDomains.map((domain) => domain.replace(/^www\./, "").toLowerCase());
  const validSourceCount = answer.sources.length >= scenario.minSources && answer.sources.length <= scenario.maxSources;
  const coversDomains = requiredHosts.every((domain) => uniqueHosts.has(domain));
  const enoughIndependentHosts = uniqueHosts.size >= requiredHosts.length;
  assertions.push(assertion(
    "sources",
    validSourceCount && coversDomains && enoughIndependentHosts,
    "sources must satisfy count and required host coverage",
  ));
  assertions.push(assertion(
    "source_claims",
    answer.sources.every((source) => answerParagraphContainsSource(answer.answerMarkdown, source)),
    "each source URL must share a paragraph with a four-character claim word",
  ));

  if (scenario.requireOpen) {
    const opened = new Set(events.filter((event) => event.action === "open" && event.url).map((event) => normalizeUrl(event.url!)));
    const everySourceOpened = answer.sources.every((source) => opened.has(normalizeUrl(source.url)));
    const openEvidenceIncomplete = input.runtime === "codex" && !everySourceOpened;
    assertions.push(assertion(
      "sources_opened",
      everySourceOpened,
      openEvidenceIncomplete
        ? "Codex captured events cannot prove whether every cited source was opened"
        : "every cited source must have matching open evidence",
      openEvidenceIncomplete,
    ));
  }

  const explicitDelegation = (event: NormalizedEvent): boolean =>
    event.action === "delegate"
    && (event.rawType === "harness"
      || (isInvocationRecord(event.rawType) && event.tool !== undefined && isDelegationTool(event.tool)));
  const actionCount = (action: ActionName) => events.filter((event) =>
    action === "delegate" ? explicitDelegation(event) : event.action === action
  ).length;
  const codexDirectSearchAmbiguity = input.runtime === "codex" && input.route === "direct";
  const delegations = actionCount("delegate");
  assertions.push(assertion(
    "delegations",
    delegations >= scenario.minDelegations && delegations <= scenario.maxDelegations,
    `expected ${scenario.minDelegations}-${scenario.maxDelegations} delegations, received ${delegations}`,
  ));
  if (scenario.maxSearches !== null) {
    const searches = actionCount("search");
    const tooManySearches = searches > scenario.maxSearches;
    assertions.push(assertion(
      "searches",
      !tooManySearches,
      tooManySearches && codexDirectSearchAmbiguity
        ? "Codex direct-route search events cannot distinguish discovery from direct retrieval"
        : `maximum ${scenario.maxSearches} searches, received ${searches}`,
      tooManySearches && codexDirectSearchAmbiguity,
    ));
  }
  const forbiddenNonSearchAction = scenario.forbiddenActions.find((action) => action !== "search" && actionCount(action) > 0);
  const forbiddenSearchObserved = scenario.forbiddenActions.includes("search") && actionCount("search") > 0;
  assertions.push(assertion(
    "forbidden_actions",
    !forbiddenNonSearchAction && !forbiddenSearchObserved,
    forbiddenSearchObserved && !forbiddenNonSearchAction && codexDirectSearchAmbiguity
      ? "Codex direct-route search events cannot prove forbidden discovery did not occur"
      : "forbidden actions must not occur",
    forbiddenSearchObserved && !forbiddenNonSearchAction && codexDirectSearchAmbiguity,
  ));
  if (scenario.requireUncertainty) {
    assertions.push(assertion("uncertainty", answer.uncertainty.trim() !== "", "uncertainty is required"));
  }

  let status: RunStatus = "pass";
  if (!processAvailable || assertions.some((entry) => entry.status === "incomplete")) {
    status = "incomplete";
  }
  if (processAvailable && assertions.some((entry) => entry.status === "fail")) {
    status = "fail";
  }
  return { ...input, status, assertions };
}

function median(values: number[]): number {
  const sorted = [...values].sort((left, right) => left - right);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle];
}

function nullableMedian(values: Array<number | null>): number | null {
  const present = values.filter((value): value is number => value !== null);
  return present.length === 0 ? null : median(present);
}

export function summarize(runs: EvaluationRun[]): EvaluationSummary {
  const runtime = runs[0]?.runtime ?? "codex";
  const variant = runs[0]?.variant ?? "baseline";
  const statusCounts: Record<RunStatus, number> = { pass: 0, fail: 0, incomplete: 0 };
  const failedScenarios: string[] = [];
  const incompleteScenarios: string[] = [];
  const staleScenarios: string[] = [];
  const grouped = new Map<string, EvaluationRun[]>();

  runs.forEach((run) => {
    statusCounts[run.status] += 1;
    if (run.status === "fail") failedScenarios.push(run.scenario.id);
    if (run.status === "incomplete") incompleteScenarios.push(run.scenario.id);
    if (run.scenario.status === "stale") staleScenarios.push(run.scenario.id);
    if (run.scenario.efficiencyProbe && run.status === "pass") {
      const key = `${run.runtime}:${run.scenario.id}`;
      grouped.set(key, [...(grouped.get(key) ?? []), run]);
    }
  });

  const efficiencyMedians: Record<string, EfficiencyMedian> = {};
  grouped.forEach((group, key) => {
    efficiencyMedians[key] = {
      modelCalls: median(group.map((run) => run.process.modelCalls)),
      inputTokens: nullableMedian(group.map((run) => run.process.inputTokens)),
      outputTokens: nullableMedian(group.map((run) => run.process.outputTokens)),
      responseChars: median(group.map((run) => run.process.responseChars)),
      elapsedMs: median(group.map((run) => run.process.elapsedMs)),
    };
  });

  return {
    runtime,
    variant,
    runs,
    statusCounts,
    failedScenarios,
    incompleteScenarios,
    staleScenarios,
    efficiencyMedians,
  };
}

function statusByScenario(summary: EvaluationSummary): Map<string, EvaluationRun> {
  const selected = new Map<string, EvaluationRun>();
  const severity: Record<RunStatus, number> = { pass: 0, incomplete: 1, fail: 2 };
  summary.runs.forEach((run) => {
    const key = `${run.runtime}:${run.scenario.id}`;
    const previous = selected.get(key);
    if (!previous || severity[run.status] > severity[previous.status]) selected.set(key, run);
  });
  return selected;
}

function metricImproves(candidate: number, baseline: number): boolean {
  return candidate < baseline;
}

function worsensByTwentyPercent(candidate: number, baseline: number): boolean {
  return baseline === 0 ? candidate > 0 : candidate > baseline * 1.2;
}

export function compareSummaries(baseline: EvaluationSummary, candidate: EvaluationSummary): Comparison {
  const baselineRuns = statusByScenario(baseline);
  const candidateRuns = statusByScenario(candidate);
  const scenarioChanges: Comparison["scenarioChanges"] = [];
  const severity: Record<RunStatus, number> = { pass: 0, incomplete: 1, fail: 2 };
  let qualityRegression = false;

  for (const [key, candidateRun] of candidateRuns) {
    const baselineRun = baselineRuns.get(key);
    if (baselineRun && baselineRun.status !== candidateRun.status) {
      scenarioChanges.push({
        runtime: candidateRun.runtime,
        scenarioId: candidateRun.scenario.id,
        baseline: baselineRun.status,
        candidate: candidateRun.status,
      });
    }
    if (!baselineRun || severity[candidateRun.status] > severity[baselineRun.status]) qualityRegression = true;
  }

  for (const [key, baselineRun] of baselineRuns) {
    if (!candidateRuns.has(key)) {
      scenarioChanges.push({
        runtime: baselineRun.runtime,
        scenarioId: baselineRun.scenario.id,
        baseline: baselineRun.status,
        candidate: "incomplete",
      });
      qualityRegression = true;
    }
  }

  const hasCandidateFailure = candidate.statusCounts.fail > 0;
  const hasCandidateIncomplete = candidate.statusCounts.incomplete > 0;
  const qualityGate: Comparison["qualityGate"] = hasCandidateFailure
    ? "fail"
    : hasCandidateIncomplete
      ? "incomplete"
      : "pass";

  const sharedMedians = Object.keys(baseline.efficiencyMedians)
    .filter((key) => key in candidate.efficiencyMedians)
    .map((key) => ({ baseline: baseline.efficiencyMedians[key], candidate: candidate.efficiencyMedians[key] }));
  let improved = false;
  let hardEfficiencyRegression = false;
  for (const pair of sharedMedians) {
    const metrics = [
      [pair.candidate.modelCalls, pair.baseline.modelCalls],
      [pair.candidate.outputTokens, pair.baseline.outputTokens],
      [pair.candidate.elapsedMs, pair.baseline.elapsedMs],
    ] as const;
    improved ||= metrics.some(([next, previous]) => next !== null && previous !== null && metricImproves(next, previous));
    hardEfficiencyRegression ||= metrics.every(([next, previous]) => next !== null && previous !== null && worsensByTwentyPercent(next, previous));
  }
  const efficiencyDecision: Comparison["efficiencyDecision"] = sharedMedians.length === 0
    ? "unavailable"
    : improved && !hardEfficiencyRegression
      ? "improved"
      : "mixed";
  const hasStale = baseline.staleScenarios.length > 0 || candidate.staleScenarios.length > 0;
  const recommendation: Comparison["recommendation"] = hasStale
    ? "review"
    : qualityRegression
      ? "reject"
      : qualityGate === "pass" && efficiencyDecision === "improved"
        ? "adopt"
        : "review";

  return { qualityGate, efficiencyDecision, recommendation, scenarioChanges };
}
