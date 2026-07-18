---
name: story-loop
description: Use when cataloging a repository's externally observable capabilities as end-to-end scenarios and driving them through test, fix, and re-test until verified
---

# Story Loop

Drive the current repository to a known-good state. Catalog every externally
observable capability as an end-to-end scenario card, then loop through test,
fix, and fresh re-test until the results are verified or explicitly parked.

**REQUIRED SUB-SKILL:** Use `e2e-scenario-testing` before Phase 0 for the card
format, interface recipes, evidence discipline, and cleanup rules.

## Scope

Use the area or surface named by the user. If the user gives no narrower scope,
cover the whole repository.

Derive expected behavior from code, tests, fixtures, schemas, comments, and
documentation. Prefer code when sources conflict. Do not guess: record
ambiguous, underspecified, unreachable, or externally blocked behavior as an
open question in the ledger.

A capability is any externally observable behavior the project exposes,
including CLI commands, public library APIs, web routes, API endpoints,
background jobs, configuration behavior, authentication flows, data formats,
integrations, migrations, plugins, build tools, and developer workflows.

## Artifacts

### Scenario cards

Create one card per capability under `test/scenarios/`, named
`<area>-<nnn>-<slug>.md`. The filename stem is the stable ID; never renumber it.
Use the `e2e-scenario-testing` card format with these additions:

- Put the actor, user story, and source references under **What this covers**.
- Put code-derived behavior under **Expected**, with one falsification
  condition per assertion.
- Put ambiguities and footguns under **Sharp edges** and in the ledger notes.

### Canonical ledger

Maintain exactly one `test/scenarios/LEDGER.md`:

| ID | Card | Status | Test method | Defect type | Actual result | Notes / open questions |
| --- | --- | --- | --- | --- | --- | --- |

The main agent is the only writer. Discovery agents, card authors, runners,
and reviewers return findings; the main agent transcribes them. Never create
per-phase, per-area, or per-iteration copies of the canonical ledger.

Status flow:

```text
Spec'd -> Tested-Pass | Tested-Fail -> Fixed -> Verified
```

- Promote a genuine executed `Tested-Pass` to `Verified` at iteration end when
  no defect was logged against it.
- A row touched by a fix reaches `Verified` only through a fresh post-fix run.
- Static-only checks stop at `Tested-Pass`; they never reach `Verified`.

Keep cards and the ledger as a version-controlled regression suite. Commit them
only within the user's authorized Git workflow.

## Phase 0: Plan

Detect the project shape:

- languages, frameworks, package managers, build and test tooling
- runtime entrypoints, public interfaces, CLIs, web and API surfaces
- background workers, persistence, configuration, auth, and permissions
- integrations and existing unit, integration, system, or end-to-end tests
- fixtures, seeds, mocks, local services, browser automation, and CI scripts

Preflight according to `e2e-scenario-testing`: build fresh from the code under
test, give the test instance its own home, port, and state directory, run a
smoke check, and confirm required credentials or models are available.

Write down:

1. How capabilities will be inventoried.
2. The stable area and ID scheme.
3. The strongest practical method for every surface.
4. What cannot run locally and how it will be reported without invented
   results.

Proceed when this plan holds.

## Phase 1: Catalog

1. Delegate discovery by independent area or interface.
2. Assign stable IDs and add a `Spec'd` ledger row for every capability.
3. Delegate card authoring. Authors may write assigned new cards only; they do
   not edit product code, test code, or existing assertions. A failing card and
   its evidence are valid deliverables.
4. Ask a fresh-context reviewer to compare the cards and ledger against the
   discoverable code surface. Fix omissions and unsupported claims.

Exit Phase 1 only when every discoverable capability in scope has a card and a
ledger row.

## Runner contract

Give each disposable runner:

- its assigned cards and an isolated workdir
- a freshly built instance with separate home, port, and mutable state
- permission to drive the real interface and capture evidence, but not to edit
  product behavior or the canonical ledger
- one retry only when the first result plausibly indicates a flake

Require the runner to return, for every assertion:

- `PASS` or `FAIL`
- the concrete observed value or rendered text
- commands, screenshots, pane captures, logs, or artifact paths as evidence
- the defect type and suspected root cause when it fails
- cleanup confirmation and anything skipped or untestable

A runner never weakens, skips, or reinterprets an assertion to make it pass.

## Quality cycle

Choose the strongest practical method for each card:

1. End-to-end or system execution against the real project.
2. CLI invocation against a freshly built local binary.
3. Public API or library calls through tests or a small harness.
4. Integration tests with real, local, or faithful fake dependencies.
5. Existing unit tests.
6. A targeted new test or harness.
7. Static checks only when execution is genuinely impossible.

### 1. Test

- Run every card not yet `Verified` through disposable runners.
- Batch cards sequentially when they share safe setup.
- Do not change product or tool behavior during this step.
- Transcribe status, method, defect type, actual result, and evidence into the
  canonical ledger.

Defect type is one of `Functional`, `Logistical`, `UX`, `Documentation`,
`Testability`, `Environment`, or `Unknown`.

### 2. Fix

For every `Functional`, `Logistical`, and `UX` defect:

- find the root cause through systematic debugging
- fix the cause, not the symptom
- limit changes to logged defects; avoid unrelated features or refactors
- update the affected ledger rows

Fix other defect types only when the correction is clear and needs no product
decision. Otherwise leave them logged with concrete notes.

Edit a card only when the card itself is wrong. Justify the edit in the ledger;
never weaken a correct assertion to make a failure pass.

### 3. Re-test

- Re-run every card touched by a fix through fresh runners, using the same
  method when possible.
- Pass becomes `Verified`; failure becomes `Tested-Fail` with root-cause notes.
- End the iteration with a fresh-context review of ledger accuracy, omitted
  results, and stale statuses.

Repeat until every capability is `Verified` and no open `Functional`,
`Logistical`, or `UX` defect remains.

## Safety cap and checkpoints

If a capability still fails after three full test, fix, and re-test iterations,
stop looping on it. Leave it `Tested-Fail` and record the root cause, attempted
fixes, remaining evidence, and recommended next action.

Pause only when:

- a destructive or irreversible action is required
- a fix needs a genuine product decision
- required input is available only from the user
- credentials or secrets are required and no safe local substitute exists

Otherwise keep going. Verify by running, not claiming. Report real commands,
outputs, and exit codes, and state every skip, unknown, missing dependency, and
untestable case plainly.
