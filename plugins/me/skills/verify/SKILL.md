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
- `/story-loop` — catalog the whole repository as scenarios, then loop to green

## What `/verify` checks

Focus on the current work context:

- the intended golden path
- the most relevant edge cases
- obvious regressions near the changed behavior
- all risk surfaces identified in Phase 0 (외부 시스템 접점은 항상 직접 검증)

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

변경된 코드가 외부 시스템 접점(OpenSearch, DB, message queue, 외부 API, 파일 시스템 등)과 상호작용하는지 식별한다.

식별 단서:

- diff에 외부 클라이언트/리포지토리/게이트웨이 호출이 포함됨
- 계획서나 Rollout 메모에 "배포 전 ~ 확인 권장" 같은 항목이 있음

각 risk surface에 대해 다음을 결정한다:

1. 어떤 호출/조회로 검증할 것인가
2. 지금 접근 가능한가 (SSO, 권한, 터널 등)

접근 불가능한 risk surface가 있으면 검증을 시작하기 전에 사용자에게 알리고, 접근 방법을 제공받거나 그 항목을 제외해도 되는지 명시적으로 확인받는다. 사용자 확인 없이 건너뛰지 않는다.

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

- **PASS** — Phase 0에서 식별된 모든 risk surface와 scenario가 검증되었고, 문제가 없음
- **PARTIAL** — 검증되지 않은 risk surface가 있거나, 일부 scenario가 실패/불완전/불확실
- **FAIL** — 핵심 scenario가 실패했거나 의도한 동작과 명백히 다름

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
but never present "수정 후 재검증" options.

### PARTIAL / FAIL

Ask how to proceed:

> "검증 결과는 PARTIAL/FAIL입니다. 수정 후 다시 검증하시겠습니까?"
> A) Subagent-driven — 수정 후 재검증 (`superpowers:subagent-driven-development`)
> B) Inline — 순차 수정 후 재검증 (`superpowers:executing-plans`)
> C) 아니오 — 리포트만 남기고 종료

If C: end.
