---
name: ship
description: Use when preparing to deploy to production, asked to "ship", "release", or "deploy", or when you need to verify a deploy succeeded or plan a rollback. Covers the full flow: pre-deploy checks, the deploy itself, and post-deploy verification with rollback on failure.
---

# Ship

## Overview

Deploy safely, observably, reversibly. Every launch goes through three phases: **pre-deploy → deploy →
post-deploy**. Don't skip phases.

## Automation Policy

Run safe read-only checks and local reversible work automatically (git/CI status, tests, lint, audits,
drafting rollout/rollback plans). Classify each finding `AUTO-COMPLETED`, `NEEDS_APPROVAL`, `BLOCKED`,
or `READY_FOR_SHIP_REVIEW`.

Ask for approval before anything that changes shared or external state: releases, deploys,
infra/flag/config/secret/DB changes, external notifications, rollbacks, destructive commands,
data migrations.

**Exception — PR flow inside ship:** push, PR creation, and merge are part of the ship flow itself,
so run them automatically without prompting. Always squash-merge via `gh pr merge --auto --squash`
(delegate to `me:create-pr`, which defaults to squash auto-merge). The user invoked ship to drive
the release end-to-end; pausing on each git step defeats the purpose.

### When to Delegate to Subagents

Fan-out is a tool, not a requirement.

- **Delegate** when 2+ independent analyses can run in parallel, a specialist fits
  (`me:security-auditor`, `me:test-engineer`, `Explore`), or output would pollute main context.
- **Run directly** when a single command answers it, the result must be reasoned about immediately,
  or blast radius is small.

When delegating, batch independent calls in one message so they run in parallel.

## Execution Workflow

Three phases: **pre-deploy → deploy → post-deploy**. Do not skip phases.

**First, classify the change:**

- **Deployable** (touches code/infra that runs in production) → full three-phase flow.
- **Non-deployable** (docs, skills, internal scripts, CI config without runtime effect) → run
  Phase 1 checks (tests/lint relevant to the change), commit/PR per normal flow, skip Phases 2–3.
  State explicitly: "Non-deployable change, skipping deploy/verify phases."

If unsure, ask the user once. Don't invent a deploy step for a doc change.

### Phase 1 — Pre-deploy (배포 전 점검)

1. **Identify scope** — launch type, changed files, blast radius, production systems touched.
2. **Read the deploy convention** — see "Reading Deploy Convention" below. If the project has none,
   ask once and offer to record the answer.
3. **Run checks** — local verification (tests, lint, type, build), CI/PR status, dependency/security
   audits, docs. For non-trivial changes consider fanning out per "When to Delegate".
4. **Draft artifacts** — rollout stages, rollback triggers/procedure, monitoring targets, owners,
   post-deploy checks.
5. **Classify and decide** — mark each item `AUTO-COMPLETED`, `NEEDS_APPROVAL`, `BLOCKED`, or
   `READY_FOR_SHIP_REVIEW`. Stop and report evidence if anything is `BLOCKED`. Present GO/NO-GO with
   the rollback plan.

### Phase 2 — Deploy (배포)

1. **Execute deploy** — run the command from the deploy convention. This is `NEEDS_APPROVAL`; never
   run without the user's explicit go-ahead.

### Phase 3 — Post-deploy (배포 후 점검)

1. **Verify** — run the checks from "Post-Deploy Verification" below. Delegate to subagents only when
   criteria in "When to Delegate" are met.
1. **On failure** — collect evidence, draft the rollback command from the deploy convention, present
   as `NEEDS_APPROVAL`. Do not auto-rollback.
1. **Report** — what shipped, what was verified, what to watch.

## Decision Categories

- `AUTO-COMPLETED`: Safe checks or drafts completed locally with evidence.
- `NEEDS_APPROVAL`: Risky, externally visible, shared-state, or hard-to-reverse actions that require user
  approval.
- `BLOCKED`: Launch blocker such as failing tests, missing rollback path, unknown owner, missing
  monitoring, unresolved security risk, or unverifiable production impact.
- `READY_FOR_SHIP_REVIEW`: Launch preparation is complete enough to produce a GO/NO-GO decision.

## Reading Deploy Convention

Deploy commands and verification endpoints live with the project, not in this skill. Before deploying,
look for a deployment section in the project's own documentation. If none exists, ask the user.

Look for:

- **Deploy command(s)** — e.g. `bun run deploy:staging`, `bun run deploy:prod`
- **Health check URL** — endpoint that returns 200 when the deploy is healthy
- **Error/log inspection command** — how to check recent errors after deploy
- **Rollback command** — exact command or procedure to revert
- **Smoke flows** — critical user journeys to verify (especially for UI changes)

If any of these are missing, ask the user once and offer to record the answers in the project's
docs so future runs are reproducible. If the user cannot provide a deploy command, mark the deploy
step `BLOCKED` and stop — do not invent one.

Also use the project's own verify commands (test, lint, build) when documented. If they conflict
with the defaults in Phase 1 step 3, the project wins.

Example convention block to suggest:

```markdown
## Deployment
- Staging: `bun run deploy:staging`
- Production: `bun run deploy:prod`
- Health check: https://api.example.com/health
- Error scan: `bun run logs:errors --since 5m`
- Rollback: `git revert HEAD && bun run deploy:prod`
- Smoke flows:
  - Login → dashboard
  - Create item → confirm in list
```

## Post-Deploy Verification

Run these checks immediately after deploy. Each is `AUTO-COMPLETED` on success; any failure becomes
`BLOCKED` and triggers the rollback flow in the Execution Workflow.

1. **Health check** — hit the health URL from the deploy convention. Expect 200 with the expected body.
2. **Error/log scan** — run the project's error scan command. Compare error rate to the baseline noted
   before deploy.
3. **UI smoke (when UI changed)** — run the smoke flows from the deploy convention. Delegate to
   `me:browse` / `me:verify` for browser-runtime checks rather than re-implementing browser automation.
4. **Critical user flow** — for production-bound changes, walk through the primary user path end-to-end.

Report each as `OK` with evidence (status code, log excerpt, screenshot path) or `FAIL` with the exact
output that failed. Do not claim success without evidence.

## When to Use

- Deploying a feature to production for the first time
- Releasing a significant change to users
- Migrating data or infrastructure
- Opening a beta or early access program
- Any deployment that carries risk (all of them)

## Pre-Launch Checklist

For the heavy categories, delegate rather than re-implement:

- **Code quality** — tests pass, lint/type/build clean, code reviewed (use `me:review`, `me:test`)
- **Security** — no secrets, audit clean, auth/CORS/rate limits in place (use `me:security-auditor`)
- **Performance / a11y** — see `references/performance-checklist.md`, `references/accessibility-checklist.md`
- **Infra / docs** — env vars set, migrations ready, health endpoint exists, docs/changelog updated

## Feature Flags

Ship behind a flag to decouple deploy from release. Each flag has an owner and expiration. Clean up
within 2 weeks of full rollout. Don't nest flags. Test both states in CI.

## Staged Rollout

Sequence: **staging → prod (flag OFF) → team → 5% canary → 25% → 50% → 100% → clean up flag**.
Monitor at each step against baseline; advance, hold, or roll back per the thresholds below.

| Metric | Advance | Hold | Roll back |
|--------|---------|------|-----------|
| Error rate | Within 10% of baseline | 10-100% above | >2x baseline |
| P95 latency | Within 20% | 20-50% above | >50% above |
| Client JS errors | No new types | New at <0.1% sessions | New at >0.1% |
| Business metrics | Neutral/positive | Decline <5% | Decline >5% |

## Rollback

Never auto-rollback. On verification failure: **collect evidence → draft rollback command from the
deploy convention → present as `NEEDS_APPROVAL`**. Rollback changes production state and warrants the
same approval gate as the deploy itself. Database migrations may need their own rollback path —
check before deploying, not after.

## See Also

- `references/security-checklist.md`, `references/performance-checklist.md`, `references/accessibility-checklist.md`

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "It works in staging, it'll work in production" | Production has different data, traffic patterns, and edge cases. Monitor after deploy. |
| "We don't need feature flags for this" | Every feature benefits from a kill switch. Even "simple" changes can break things. |
| "Monitoring is overhead" | Not having monitoring means you discover problems from user complaints instead of dashboards. |
| "We'll add monitoring later" | Add it before launch. You can't debug what you can't see. |
| "Rolling back is admitting failure" | Rolling back is responsible engineering. Shipping a broken feature is the failure. |

## Red Flags

- Deploying without a rollback plan
- No monitoring or error reporting in production
- Big-bang releases (everything at once, no staging)
- Feature flags with no expiration or owner
- No one monitoring the deploy for the first hour
- Production environment configuration done by memory, not code
- "It's Friday afternoon, let's ship it"

## Verification

- **Before deploying:** Pre-Launch Checklist sections green, rollback plan drafted, feature flag
  configured if applicable.
- **After deploying:** see "Post-Deploy Verification" above.
