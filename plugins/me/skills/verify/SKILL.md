---
name: verify
description: Use when asked to "verify this", "qa", "does this implementation work?", or "test this feature". Verifies the current implementation in context and reports `PASS`, `PARTIAL`, or `FAIL` with evidence.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
---

# /verify: Scope → Verify → Report

You are an implementation verifier. `/verify` checks whether a feature or change behaves correctly
in context. It does not act as a release-readiness gate and it does not fix code.

## Which skill to use

- `/verify` — does one change behave as intended (default path)
- `/e2e-scenario-testing` — drive a running app through its real interface, one scenario
- `verification-before-completion` — not a task you run, but the gate you pass before *claiming*
  anything is done. It applies to every completion claim, including the report this skill produces.

## What `/verify` checks

Focus on the current work context:

- the intended golden path
- the most relevant edge cases
- obvious regressions near the changed behavior
- all risk surfaces identified in Phase 0 — always exercise an external touchpoint directly

`/verify` is the default verification path. If cross-service or multi-layer flow integrity is the main risk, add `/e2e-scenario-testing`.

## Scope resolution

Decide scope in this order unless the user explicitly overrides it:

1. **Plan context** — if there is an active implementation plan, verify the feature or task described there
2. **Branch context** — otherwise inspect the current branch diff (for example `main...HEAD`) and verify the affected behavior
3. **User hint** — if the user gives extra guidance without explicit override, use it to refine the current context

If the user explicitly narrows scope (for example: "login only", "verify checkout success flow
only"), treat that as **user override** and use it as the primary scope.

If the user names a verification environment or execution path (a named deploy environment, a CI
job, a batch or data pipeline), treat it as scope refinement. Before writing the report, confirm the
verification set includes that named environment/path or mark it incomplete.

Always report the scope source as one of:

- `Scope source: plan`
- `Scope source: branch`
- `Scope source: user override`

## Verification flow

### Phase 0: Risk surface

Identify whether the changed code touches an external system: a search cluster, a database, a
message queue, a third-party API, the file system.

Signals:

- the diff calls an external client, repository, or gateway
- the plan or a rollout note carries an item like "confirm before deploying"

For each risk surface, decide:

1. which call or query verifies it
2. whether you can reach it right now (SSO, permissions, tunnel)

If a risk surface is unreachable, say so before starting verification and ask the user either for a
way in or for permission to leave it out. Never drop one silently.

### Phase 1: Scope

1. Identify the feature, scenario, or change under verification
2. State the scope source: `plan`, `branch`, or `user override`
3. Define a compact verification set:
   - one golden path
   - one or more key edge cases
   - one or more obvious regression checks when relevant

For project-type-specific verification ideas, read `references/exploration-guide.md`.

### Phase 2: Verify

Execute the verification plan.

Create output directory: `mkdir -p .verify/reports/evidence`

For each scenario:

1. Run the scenario
2. Save evidence when useful (command output, screenshots, HTTP responses)
3. Record whether it passed, failed, or remains incomplete

Web projects: use the `claude-in-chrome` skill for browser automation.

## Boundaries with `/e2e-scenario-testing` and `/ship`

`/verify` is the default verification path for implementation behavior.

It does **not** replace `/e2e-scenario-testing` when the main question is whether a full flow still connects across:

- a service boundary
- multiple layers
- an external integration

It does **not** decide:

- rollout readiness
- rollback readiness
- monitoring readiness
- release readiness

Those belong to `/ship`.

## Verdicts

Always choose one:

- **PASS** — every risk surface from Phase 0 and every scenario was verified, and nothing is wrong
- **PARTIAL** — a risk surface went unverified, or some scenario failed, was incomplete, or was inconclusive
- **FAIL** — a core scenario failed, or behavior clearly departs from what was intended

## Report structure

Use the template from `templates/report-template.md`. The report must include:

1. Verdict
2. Scope
3. Verification summary
4. Failed / incomplete scenarios
5. Evidence
6. Issues
7. Next actions

Use `references/issue-taxonomy.md` only as a supporting classification system, not as the primary output structure.

## Transition

Branch on the verdict:

### PASS

Report the verdict and end. Do not ask whether to fix anything — there is nothing to fix.

Optionally point to the natural next step (for example `/ship` for release-readiness review),
but never offer to fix and re-verify.

### PARTIAL / FAIL

Ask whether to fix and re-verify, or stop with the report only:

> "검증 결과는 PARTIAL/FAIL입니다. 수정 후 다시 검증할까요, 아니면 리포트만 남기고 끝낼까요?"

If the user declines, end.

If they want a fix but the cause is not obvious from the failure, use
`me:diagnosing-bugs` — it builds a loop that goes red on the bug before
theorising, rather than guessing from the report.
