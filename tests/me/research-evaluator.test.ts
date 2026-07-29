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

function scoreOpenEvidence(
  runtime: "codex" | "claude",
  events: EvaluationRun["events"],
): EvaluationRun {
  return scoreRun({
    runtime,
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
      maxSearches: null,
      minDelegations: 0,
      maxDelegations: 0,
      forbiddenActions: [],
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
    events,
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

  test("does not treat Codex assistant output as delegation", () => {
    const events = normalizeEvents("codex", [
      JSON.stringify({
        type: "item.completed",
        item: { type: "agent_message", text: "I will answer directly." },
      }),
    ]);
    expect(events.filter((event) => event.action === "delegate")).toEqual([]);
  });

  test("does not treat an agent-browser invocation as delegation", () => {
    const events = normalizeEvents("codex", [
      JSON.stringify({
        type: "item.completed",
        item: {
          type: "mcp_tool_call",
          tool: "agent-browser",
          arguments: { url: "https://example.com" },
        },
      }),
    ]);
    expect(events.filter((event) => event.action === "delegate")).toEqual([]);
  });

  test("counts one explicit dispatch without traversing its payload as another", () => {
    const events = normalizeEvents("codex", [
      JSON.stringify({
        type: "item.completed",
        item: {
          type: "mcp_tool_call",
          tool: "spawn_agent",
          arguments: { name: "agent_worker" },
        },
      }),
    ]);
    expect(events.filter((event) => event.action === "delegate")).toEqual([{
      action: "delegate",
      tool: "spawn_agent",
      url: undefined,
      rawType: "mcp_tool_call",
    }]);
  });
});

describe("quality scoring", () => {
  test("marks missing Codex open evidence incomplete even when search events are visible", () => {
    const run = scoreOpenEvidence("codex", [{
      action: "search",
      tool: "web_search",
      rawType: "web_search",
    }]);
    expect(run.status).toBe("incomplete");
    expect(run.assertions).toContainEqual(expect.objectContaining({
      name: "sources_opened",
      status: "incomplete",
      detail: "Codex captured events cannot prove whether every cited source was opened",
    }));
  });

  test("fails missing open evidence when the runtime protocol can prove opens", () => {
    const run = scoreOpenEvidence("claude", [{
      action: "search",
      tool: "WebSearch",
      rawType: "tool_use",
    }]);
    expect(run.status).toBe("fail");
    expect(run.assertions).toContainEqual(expect.objectContaining({
      name: "sources_opened",
      status: "fail",
    }));
  });

  test("marks Codex direct search ambiguity incomplete but keeps Claude and researcher routes strict", () => {
    const input = syntheticSummary("baseline", "pass", 50).runs[0];
    input.scenario.maxSearches = 0;
    input.scenario.forbiddenActions = ["search"];
    input.events = [{ action: "search", tool: "web_search", rawType: "web_search" }];

    const codexDirect = scoreRun(input);
    expect(codexDirect.status).toBe("incomplete");
    expect(codexDirect.assertions).toContainEqual({
      name: "searches",
      status: "incomplete",
      detail: "Codex direct-route search events cannot distinguish discovery from direct retrieval",
    });
    expect(codexDirect.assertions).toContainEqual({
      name: "forbidden_actions",
      status: "incomplete",
      detail: "Codex direct-route search events cannot prove forbidden discovery did not occur",
    });

    const claudeDirect = scoreRun({ ...input, runtime: "claude" });
    expect(claudeDirect.status).toBe("fail");
    expect(claudeDirect.assertions).toContainEqual(expect.objectContaining({
      name: "searches",
      status: "fail",
    }));
    expect(claudeDirect.assertions).toContainEqual(expect.objectContaining({
      name: "forbidden_actions",
      status: "fail",
    }));

    const codexResearcher = scoreRun({
      ...input,
      route: "researcher",
      scenario: { ...input.scenario, expectedRoute: "researcher" },
    });
    expect(codexResearcher.status).toBe("fail");
    expect(codexResearcher.assertions).toContainEqual(expect.objectContaining({
      name: "searches",
      status: "fail",
    }));
    expect(codexResearcher.assertions).toContainEqual(expect.objectContaining({
      name: "forbidden_actions",
      status: "fail",
    }));
  });

  test("keeps non-search forbidden actions strict for Codex direct routes", () => {
    const input = syntheticSummary("baseline", "pass", 50).runs[0];
    input.scenario.forbiddenActions = ["search", "open"];
    input.events = [
      { action: "search", tool: "web_search", rawType: "web_search" },
      { action: "open", tool: "open", rawType: "tool_use" },
    ];

    const run = scoreRun(input);
    expect(run.status).toBe("fail");
    expect(run.assertions).toContainEqual(expect.objectContaining({
      name: "forbidden_actions",
      status: "fail",
    }));
  });

  test("counts only explicit saved delegation events", () => {
    const savedRun = syntheticSummary("baseline", "pass", 50).runs[0];
    savedRun.route = "researcher";
    savedRun.scenario.expectedRoute = "researcher";
    savedRun.scenario.minDelegations = 1;
    savedRun.scenario.maxDelegations = 1;
    savedRun.events = [
      { action: "delegate", tool: "agent_message", rawType: "agent_message" },
      { action: "delegate", tool: "agent_message", rawType: "agent_message" },
      { action: "delegate", tool: "harness", rawType: "harness" },
    ];

    const rescored = scoreRun(savedRun);
    expect(rescored.assertions).toContainEqual({
      name: "delegations",
      status: "pass",
      detail: "expected 1-1 delegations, received 1",
    });
  });

  test("does not report saved assistant output as a forbidden delegation", () => {
    const savedRun = syntheticSummary("baseline", "pass", 50).runs[0];
    savedRun.scenario.forbiddenActions = ["delegate"];
    savedRun.events = [
      { action: "delegate", tool: "agent_message", rawType: "agent_message" },
    ];

    const rescored = scoreRun(savedRun);
    expect(rescored.assertions).toContainEqual({
      name: "forbidden_actions",
      status: "pass",
      detail: "forbidden actions must not occur",
    });
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
