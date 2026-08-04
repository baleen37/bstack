# Research Skill and Evaluation Redesign

**Date:** 2026-07-29

**Status:** Approved for implementation planning

**Supersedes:** `2026-07-25-external-research-subagent-design.md`

## Context

The current research skill has the intended high-level shape: a small routing
skill delegates discovery to one read-only researcher. Its behavior is not
reliably measurable yet.

Two staging-only SkillOpt runs did not improve the validation score:

- Run 1 proposed four edits, but the validation gate rejected all of them.
- Run 2 proposed no edits.
- One held-out task produced an empty response in both runs.
- The three-task evaluation set had no durable, checkable reference contract.
- The current Scope wording can be read as forbidding browsing and delegation
  for every request, even though later sections require those actions.

The problem is therefore both instructional and evaluative. Rewriting the
skill without a stable behavioral baseline would make improvement claims
unverifiable.

## Goals

1. Make source accuracy and claim support the primary acceptance gate.
2. Keep the dispatcher small and put detailed research behavior in the
   researcher agent.
3. Adapt evidence depth to the request instead of using a fixed token or source
   limit.
4. Measure model calls, tokens, response length, and elapsed time after quality
   requirements pass.
5. Provide the same scenario contract and scorer for Codex and Claude.
6. Keep every candidate change staged until its exact diff and evaluation
   results are reviewed.

## Non-goals

- Local codebase exploration or local bug diagnosis.
- Multi-researcher fan-out.
- Exhaustive browsing after the evidence requirement is satisfied.
- A hard token, response-length, or latency ceiling.
- Automatic adoption of SkillOpt output.
- Testing `SKILL.md` wording or frontmatter with string assertions.

## Architecture

### Thin dispatcher

`plugins/me/skills/research/SKILL.md` will be rewritten as a compact dispatcher,
approximately 150 to 200 words. It will perform only four jobs:

1. Classify the request.
2. Route out-of-scope work without browsing or delegation.
3. Handle an exact supplied source directly.
4. Delegate source discovery once to `me:researcher`, with a direct-research
   fallback when delegation is unavailable or fails.

The dispatcher returns the answer, claim-bearing sources, and material
uncertainty. It does not contain the full search methodology.

### Researcher contract

`plugins/me/agents/researcher.md` will own the research process:

- identify the source owner before broad discovery;
- open and read source bodies before relying on them;
- match evidence depth to the decision;
- distinguish direct evidence from inference;
- stop when the evidence contract is met;
- return a compact answer with citations next to supported claims;
- disclose unresolved conflicts and missing authoritative answers.

The researcher remains read-only and external-only.

## Routing and Evidence Budget

| Request class | Route | Evidence target |
| --- | --- | --- |
| Local code or local bug | Return an out-of-scope route | No browsing or delegation |
| Exact URL or named document | Open and inspect it directly | The supplied source |
| Narrow current fact | One researcher when discovery is needed | One owning or authoritative source |
| Comparison or recommendation | One researcher | Two to three independent, claim-bearing sources |
| Conflicting, high-risk, or unclear claim | One researcher, expanding only as needed | Enough evidence to explain the conflict and remaining gap |

These are evidence targets, not fixed quotas. A source that repeats an existing
claim adds no value. A missing or conflicting authoritative answer justifies
additional work. The run stops once the requested claims are supported and
material uncertainty is explicit.

## Data Flow

```text
request
  -> classify
     -> local/out-of-scope: concise route
     -> exact source: direct open and read
     -> discovery needed: one researcher
  -> open source bodies
  -> check evidence contract
  -> compact answer, nearby citations, and material gaps
```

## Behavioral Evaluator

The repository will gain a durable evaluator rather than another prose-only
checklist.

### Files

```text
plugins/me/skills/research/
  evals/
    scenarios.json
    result.schema.json
  scripts/
    evaluate.ts
tests/me/
  research-eval.bats
```

`evaluate.ts` will be a Bun TypeScript CLI. It will support:

- `--runtime codex|claude`
- `--variant baseline|candidate`
- scenario selection
- an explicit output directory
- a dry validation mode for scenario and result schemas

The baseline and candidate instructions will be injected into fresh,
non-persistent runs. The evaluator will not install or mutate global skills.
External operations will be read-only.

Runtime adapters will normalize their event streams into one record:

- runtime, variant, and scenario ID;
- process status and structured final answer;
- elapsed time and available token counts;
- observed search, open, and delegation events;
- cited URLs and source domains;
- deterministic assertion results.

If a runtime cannot expose evidence needed for an assertion, that run is
`incomplete`, never `pass`.

### Scenario set

The initial suite will contain about ten checkable scenarios:

1. An exact GitHub URL.
2. Current library usage from official documentation.
3. A single release or version fact.
4. A technology comparison.
5. A recommendation involving cost, rate limits, and privacy.
6. A paper or standard.
7. Conflicting sources.
8. No documented official answer.
9. An out-of-scope local bug.
10. A repeated or redundant search pressure case.

Each scenario declares observable requirements such as:

- expected claims or acceptable answer states;
- required source owners or domains;
- minimum and maximum independent source counts where meaningful;
- whether a source body must be opened;
- allowed delegation count;
- forbidden actions;
- whether an explicit uncertainty statement is required.

Current facts must carry a reference date. When the source has legitimately
changed, the scenario is marked stale and refreshed explicitly. Expected output
is never changed merely to make a candidate pass.

### Scoring

Quality and efficiency remain separate.

The quality gate checks:

- non-empty successful output for in-scope requests;
- required claims or a justified unavailable-answer state;
- source body inspection;
- claim-bearing citations placed near the claims;
- correct routing and delegation count;
- absence of forbidden research actions;
- explicit treatment of conflicts and material gaps.

Efficiency reporting includes:

- model and tool calls;
- input and output tokens when available;
- response length;
- elapsed time;
- redundant source or search events.

A faster candidate cannot compensate for a failed critical quality assertion.
Among candidates that pass the same quality gate, fewer calls, tokens, and
redundant actions are preferred. There is no fixed token ceiling.

### Repetition policy

The full baseline and candidate suite runs once initially. Failed, empty,
variant-sensitive, and efficiency-comparison cases run three times to identify
flakiness and produce a median. Small behavior-shaping wording experiments use
at least five inexpensive repetitions before the wording is accepted. This
concentrates token spend where variance can change the decision.

## Acceptance Criteria

The redesign is accepted when:

1. Every in-scope scenario returns a non-empty answer.
2. The local-bug scenario performs no search, source opening, or delegation.
3. The exact-URL scenario performs no discovery search or delegation.
4. A narrow fact uses an owning or authoritative source.
5. Comparisons and recommendations use two to three independent sources unless
   the answer explains why that evidence is unavailable.
6. Every relied-upon web source has an observed body-open event.
7. Conflicts, inference, and missing official answers are labeled explicitly.
8. Critical quality assertions have no regression from baseline.
9. Simple passing scenarios show reduced median calls, output tokens, or
   elapsed time, with all efficiency deltas reported.
10. Evaluation artifacts preserve the exact variant, scenario, normalized
    trace, assertions, and metrics needed to reproduce the decision.

## Failure Handling

- Missing CLI or authentication: mark the runtime incomplete with the exact
  reason.
- Process failure or malformed structured output: fail the run.
- Missing tool trace required by an assertion: mark the run incomplete.
- Dynamic source drift: suspend and refresh the scenario with review.
- Intermittent empty output: retain the failure and trigger repetition.
- SkillOpt candidate: keep it in staging until the evaluator passes and the
  exact diff is approved.

## Privacy and Safety

- Use public prompts and public sources in the durable suite.
- Do not harvest archived sessions, private repositories, or private
  transcripts for routine evaluation.
- Run external research with read-only permissions.
- Keep credentials and raw authentication material out of artifacts.

## Delivery Sequence

1. **RED:** implement the evaluator and record current-skill failures.
2. **GREEN:** rewrite the dispatcher and researcher contract to satisfy the
   approved behavior.
3. **REFACTOR:** simplify wording while retaining behavior through repeated
   pressure tests.
4. Run targeted evaluator tests, both runtime adapters where available,
   `bash tests/run-all-tests.sh`, and `git diff --check`.
5. Review the quality report, efficiency deltas, and exact diff.
6. Optionally run SkillOpt against the stable evaluator in staging mode.
7. Adopt only after explicit approval.

## Verification Commands

The implementation plan may refine flags, but the intended interface is:

```bash
bun plugins/me/skills/research/scripts/evaluate.ts --validate
bun plugins/me/skills/research/scripts/evaluate.ts \
  --runtime codex --variant baseline --output-dir .tmp/research-eval/baseline
bun plugins/me/skills/research/scripts/evaluate.ts \
  --runtime codex --variant candidate --output-dir .tmp/research-eval/candidate
bats tests/me/research-eval.bats
bash tests/run-all-tests.sh
git diff --check
```

Claude runs use the same command with `--runtime claude`. Runtime-specific CLI
details belong inside the adapters, while scenario semantics and scoring stay
shared.
