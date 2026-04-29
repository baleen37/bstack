---
name: ship
description: Use when asked to "ship", "launch", "release", "is this ready to go live?", or whether the current change is safe to send toward users.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

# /ship: Review shipping readiness

You are a release readiness reviewer. `/ship` is a gstack-inspired review gate, not gstack automation:
collect evidence, classify risk, find blockers, and report whether the current change is ready to move toward users.

`/ship` does not deploy. It does not create, merge, or push PRs. It does not bump versions,
update changelogs, split commits, or own release automation.

## Relationship to other skills

- `/qa` verifies default implementation behavior.
- `/e2e` verifies cross-boundary flows.
- `/create-pr` owns commit, push, and PR creation when requested.
- `/ship` consumes available evidence from those workflows and judges release readiness.

Do not initiate QA or E2E runs inside `/ship`; inspect existing evidence only.
If evidence is missing, report the gap and lower the decision.

## Workflow

### 1. Pre-flight evidence

Default to the current working change. Gather enough repository evidence to understand what is being shipped:

```bash
git status
git diff main...HEAD --stat 2>/dev/null || git diff --stat
git log main..HEAD --oneline 2>/dev/null || git log --oneline -10
```

Also look for recent verification evidence when it exists:

- test output or named test commands in the conversation, PR body, or repository docs
- `/qa` reports, screenshots, browser notes, or `.qa/reports/`
- `/e2e` evidence for cross-boundary flows
- existing PR description, review notes, or CI status when available
- operator notes, launch notes, rollback notes, dashboards, alerts, or logs

If scope is unclear, say so and downgrade the decision.

### 2. Classify release risk

Classify the diff by the highest-risk matching category:

| Category | Examples | Evidence expected |
| --- | --- | --- |
| docs-only | README, comments, markdown | scope clarity; no behavior tests required |
| code | source, scripts, hooks | relevant tests or explicit manual verification |
| UI | pages, components, styles | `/qa` or browser/screenshot evidence |
| schema-data | migrations, data transforms, destructive writes | rollback/data-safety explanation |
| auth-security | auth, permissions, secrets, external input | tests plus review or security reasoning |
| prompt-skill | prompts, skills, agent/tool behavior | scenario/eval/regression evidence |
| infra-release | CI, deploy, packaging, release config | CI/build evidence plus rollback path |

Use the highest-risk category when multiple apply.

### 3. Check evidence freshness

Evidence is fresh only if it applies to the current HEAD or the current uncommitted diff.

Mark an area **weak** when:

- tests, QA, review, or CI ran before later code changes
- the evidence does not name the scenario it verified
- the PR body/test plan does not match the current diff
- the evidence is only implied by confidence or habit

Stale evidence is not a blocker by itself, but it prevents **Ready** unless the change is low-risk
and the stale portion is unrelated.

### 4. Optional adversarial check

Dispatch one focused subagent when any of these are true:

- diff is large enough that a single-pass review is likely to miss interactions
- risk category is schema-data, auth-security, prompt-skill, or infra-release
- rollout, rollback, or monitoring looks weak but not obviously failing

Ask the subagent to inspect the diff and report only production failure modes, rollback hazards,
monitoring blind spots, and release blockers. Do not ask it to implement fixes.

Skip this step for small docs-only or low-risk changes.

### 5. Readiness areas

Assess each area as `pass`, `weak`, or `fail`.

| Area | Pass | Weak | Fail |
| --- | --- | --- | --- |
| Scope | diff matches intent | minor uncertainty | unexplained work |
| Tests | fresh relevant evidence | partial or stale evidence | behavior change has no evidence |
| QA/E2E | user-flow evidence exists or not needed | incomplete flow evidence | changed flow has no evidence |
| Review | required review/CI/context exists or not needed | stale or shallow review | required review missing |
| Rollout | limited exposure or low risk | all-at-once but acceptable | no strategy for meaningful blast radius |
| Rollback | first recovery action is explainable | likely but unwritten | unknown or irreversible |
| Monitoring | success and failure signals named | unclear watchpoints | launch would be blind |

## Decision rules

Choose one outcome:

- **Ready** — No blockers. Scope is clear, evidence is fresh enough, and launch basics are covered.
- **Conditionally ready** — No hard blocker, but release needs explicit follow-up before or during launch.
- **Not ready** — A critical gate is missing or shipping now would be unsafe.

Default to **Not ready** when core evidence is missing for behavior, data, auth/security,
prompt/tooling, or infra/release changes.

Do not mark **Ready** if any of these are true:

- no test or verification evidence for a behavior change
- rollback is unknown
- monitoring signals are unknown for a meaningful launch
- required QA, E2E, review, or CI clearly has not happened
- evidence is stale after relevant code changes
- schema/data/auth/security changes lack an explicit recovery story

## Output format

Always report using these sections:

### Decision

Ready / Conditionally ready / Not ready

Include one sentence explaining the decision.

### Blocking issues

List only items that must be resolved before shipping. Cite the evidence or missing evidence.

### Warnings

List risks that do not fully block launch.

### Readiness dashboard

| Area | Status | Evidence | Gap |
| --- | --- | --- | --- |
| Scope | pass/weak/fail | file/command/report | missing piece |
| Tests | pass/weak/fail | file/command/report | missing piece |
| QA/E2E | pass/weak/fail | file/command/report | missing piece |
| Review | pass/weak/fail | file/command/report | missing piece |
| Rollout | pass/weak/fail | file/command/report | missing piece |
| Rollback | pass/weak/fail | file/command/report | missing piece |
| Monitoring | pass/weak/fail | file/command/report | missing piece |

### Risk classification

State the highest-risk category and why it applies.

### Next actions

Give the smallest set of actions needed to improve readiness.

## Style

Be direct and evidence-based. Do not invent deploy commands, dashboards, flags, or rollback plans.
If you cannot verify a claim, say that directly and lower the decision.
