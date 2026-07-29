import { describe, expect, test } from "bun:test";
import {
  compareSummaries,
  normalizeEvents,
  scoreRun,
  validateScenarios,
  validateResultSchema,
  type EvaluationRun,
  type EvaluationSummary,
  type RunStatus,
  type VariantName,
} from "../../plugins/me/skills/research/scripts/evaluator";

function syntheticSummary(
  variant: VariantName,
  status: RunStatus,
  outputTokens: number,
): EvaluationSummary {
  const run = {
    runtime: "codex",
    variant,
    scenario: {
      id: "synthetic",
      prompt: "question",
      asOf: null,
      status: "active",
      staleReason: null,
      expectedRoute: "direct",
      expectedAnswerStates: ["supported"],
      requiredPatterns: [],
      requiredDomains: [],
      minSources: 0,
      maxSources: 0,
      requireOpen: false,
      maxSearches: 0,
      minDelegations: 0,
      maxDelegations: 0,
      forbiddenActions: [],
      requireUncertainty: false,
      efficiencyProbe: true,
    },
    route: "direct",
    answer: {
      answerState: "supported",
      answerMarkdown: "answer",
      sources: [],
      uncertainty: "",
    },
    events: [],
    process: {
      exitCode: 0,
      availability: "available",
      failureDetail: "",
      elapsedMs: 10,
      modelCalls: 1,
      inputTokens: 100,
      outputTokens,
      responseChars: 6,
    },
    instructionHashes: { skill: "a", researcher: "b" },
    status,
    assertions: [],
  } satisfies EvaluationRun;

  return {
    runtime: "codex",
    variant,
    runs: [run],
    statusCounts: {
      pass: status === "pass" ? 1 : 0,
      fail: status === "fail" ? 1 : 0,
      incomplete: status === "incomplete" ? 1 : 0,
    },
    failedScenarios: status === "fail" ? ["synthetic"] : [],
    incompleteScenarios: status === "incomplete" ? ["synthetic"] : [],
    staleScenarios: [],
    efficiencyMedians: {
      "codex:synthetic": {
        modelCalls: 1,
        inputTokens: 100,
        outputTokens,
        responseChars: 6,
        elapsedMs: 10,
      },
    },
  };
}

describe("scenario validation", () => {
  test("accepts the public scenario contract", async () => {
    const value = await Bun.file(
      "plugins/me/skills/research/evals/scenarios.json",
    ).json();
    expect(() => validateScenarios(value)).not.toThrow();
    expect(value).toHaveLength(10);
  });

  test("accepts the structured answer schema", async () => {
    const value = await Bun.file(
      "plugins/me/skills/research/evals/result.schema.json",
    ).json();
    expect(() => validateResultSchema(value)).not.toThrow();
  });

  test("rejects an empty id with an exact path", () => {
    expect(() =>
      validateScenarios([{
        id: "",
        prompt: "question",
        asOf: null,
        status: "active",
        staleReason: null,
        expectedRoute: "direct",
        expectedAnswerStates: ["supported"],
        requiredPatterns: [],
        requiredDomains: [],
        minSources: 0,
        maxSources: 1,
        requireOpen: false,
        maxSearches: null,
        minDelegations: 0,
        maxDelegations: 0,
        forbiddenActions: [],
        requireUncertainty: false,
        efficiencyProbe: false,
      }]),
    ).toThrow("scenarios[0].id must be a non-empty string");
  });
});

describe("event normalization", () => {
  test("extracts Codex search, open, delegation, and usage events", () => {
    const events = normalizeEvents("codex", [
      JSON.stringify({
        type: "item.completed",
        item: { type: "web_search", query: "RFC 9110 safe methods" },
      }),
      JSON.stringify({
        type: "item.completed",
        item: {
          type: "mcp_tool_call",
          tool: "open",
          arguments: { ref_id: "https://www.rfc-editor.org/rfc/rfc9110" },
        },
      }),
      JSON.stringify({
        type: "turn.completed",
        usage: { input_tokens: 120, output_tokens: 40 },
      }),
    ]);
    expect(events.map((event) => event.action)).toContain("search");
    expect(events.map((event) => event.action)).toContain("open");
    expect(events.at(-1)?.inputTokens).toBe(120);
  });

  test("extracts Claude WebFetch and usage events", () => {
    const events = normalizeEvents("claude", [
      JSON.stringify({
        type: "assistant",
        message: {
          content: [{
            type: "tool_use",
            name: "WebFetch",
            input: { url: "https://www.rfc-editor.org/rfc/rfc9110" },
          }],
          usage: { input_tokens: 90, output_tokens: 25 },
        },
      }),
    ]);
    expect(events[0]).toMatchObject({
      action: "open",
      url: "https://www.rfc-editor.org/rfc/rfc9110",
    });
  });
});

describe("quality scoring", () => {
  test("fails a cited source that was never opened", () => {
    const run = scoreRun({
      runtime: "codex",
      variant: "baseline",
      scenario: {
        id: "exact-rfc-safe-methods",
        prompt: "question",
        asOf: null,
        status: "active",
        staleReason: null,
        expectedRoute: "direct",
        expectedAnswerStates: ["supported"],
        requiredPatterns: ["GET"],
        requiredDomains: ["rfc-editor.org"],
        minSources: 1,
        maxSources: 1,
        requireOpen: true,
        maxSearches: 0,
        minDelegations: 0,
        maxDelegations: 0,
        forbiddenActions: ["search", "delegate"],
        requireUncertainty: false,
        efficiencyProbe: true,
      },
      route: "direct",
      answer: {
        answerState: "supported",
        answerMarkdown:
          "GET is safe ([RFC 9110](https://www.rfc-editor.org/rfc/rfc9110)).",
        sources: [{
          title: "RFC 9110",
          url: "https://www.rfc-editor.org/rfc/rfc9110",
          claim: "GET is safe",
        }],
        uncertainty: "",
      },
      events: [],
      process: {
        exitCode: 0,
        availability: "available",
        failureDetail: "",
        elapsedMs: 10,
        modelCalls: 2,
        inputTokens: 100,
        outputTokens: 30,
        responseChars: 79,
      },
      instructionHashes: { skill: "a", researcher: "b" },
    });
    expect(run.status).toBe("incomplete");
    expect(run.assertions).toContainEqual(expect.objectContaining({
      name: "sources_opened",
      status: "incomplete",
    }));
  });

  test("keeps efficiency separate from critical quality", () => {
    const comparison = compareSummaries(
      syntheticSummary("baseline", "pass", 200),
      syntheticSummary("candidate", "fail", 50),
    );
    expect(comparison.qualityGate).toBe("fail");
    expect(comparison.recommendation).toBe("reject");
  });
});
