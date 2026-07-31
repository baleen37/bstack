---
name: ship
description: >-
  Use when preparing to deploy to production, asked to "ship", "release", or "deploy", or when
  you need to verify a deploy succeeded or plan a rollback. Covers the full flow: pre-deploy
  checks, the deploy itself, and post-deploy verification with rollback on failure.
---

# Ship

Deploy safely, observably, reversibly. Every launch goes through three phases:
**pre-deploy → deploy → post-deploy**. Don't skip phases.

## Automation Policy

Run safe read-only checks and local reversible work automatically (git/CI status, tests, lint, audits,
drafting rollout/rollback plans). Classify each finding `AUTO-COMPLETED`, `NEEDS_APPROVAL`, `BLOCKED`,
or `READY_FOR_SHIP_REVIEW`.

Ask for approval before anything that changes shared or external state: pushes, PR creation/merge,
releases, deploys, infra/flag/config/secret/DB changes, external notifications, rollbacks, destructive
commands, data migrations.

**Delegate** when 2+ independent analyses can run in parallel, a specialist fits
(`me:security-auditor`, `me:test-engineer`, `Explore`), or output would pollute main context.
**Run directly** when a single command answers it, the result must be reasoned about immediately,
or blast radius is small. Batch independent delegations in one message so they run in parallel.

## Execution Workflow

**First, classify the change:**

- **Deployable** (touches code/infra that runs in production) → full three-phase flow.
- **Non-deployable** (docs, skills, internal scripts, CI config without runtime effect) → run
  Phase 1 checks relevant to the change, commit/PR per normal flow, skip Phases 2–3.
  State explicitly: "Non-deployable change, skipping deploy/verify phases."

If unsure, ask the user once. Don't invent a deploy step for a doc change.

### Phase 1 — Pre-deploy (배포 전 점검)

1. **Identify scope** — launch type, changed files, blast radius, production systems touched.
2. **Read the deploy convention** — see below. If the project has none, ask once and offer to
   record the answer.
3. **Run checks** — local verification (tests, lint, type, build), CI/PR status, dependency/security
   audits. Use the project's own commands when documented; the project wins over any default.
4. **Draft artifacts** — rollout stages, rollback triggers/procedure, monitoring targets, owners,
   post-deploy checks.
5. **Classify and decide** — mark each item `AUTO-COMPLETED`, `NEEDS_APPROVAL`, `BLOCKED`, or
   `READY_FOR_SHIP_REVIEW`. Stop and report evidence if anything is `BLOCKED`. Present GO/NO-GO with
   the rollback plan.

### Phase 2 — Deploy (배포)

Run the command from the deploy convention. This is `NEEDS_APPROVAL`; never run without the user's
explicit go-ahead.

### Phase 3 — Post-deploy (배포 후 점검)

1. **Verify** — run the checks in "Post-Deploy Verification" below.
2. **On failure** — collect evidence, draft the rollback command from the deploy convention, present
   as `NEEDS_APPROVAL`. Do not auto-rollback.
3. **Report** — what shipped, what was verified, what to watch.

## Decision Categories

- `AUTO-COMPLETED`: Safe checks or drafts completed locally with evidence.
- `NEEDS_APPROVAL`: Risky, externally visible, shared-state, or hard-to-reverse actions.
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

If any are missing, ask the user once and offer to record the answers in the project's docs so future
runs are reproducible. If the user cannot provide a deploy command, mark the deploy step `BLOCKED`
and stop — do not invent one.

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

Run these immediately after deploy. Each is `AUTO-COMPLETED` on success; any failure becomes
`BLOCKED` and triggers the rollback flow.

1. **Health check** — hit the health URL. Expect 200 with the expected body.
2. **Error/log scan** — run the project's error scan command. Compare error rate to the baseline
   noted before deploy.
3. **UI smoke (when UI changed)** — run the smoke flows from the deploy convention. Delegate browser
   runtime checks to `me:verify` / `claude-in-chrome` rather than re-implementing automation.
4. **Critical user flow** — for production-bound changes, walk the primary user path end-to-end.

Report each as `OK` with evidence (status code, log excerpt, screenshot path) or `FAIL` with the
exact output that failed. Do not claim success without evidence.

## Rollback

Never auto-rollback. On verification failure: **collect evidence → draft rollback command from the
deploy convention → present as `NEEDS_APPROVAL`**. Rollback changes production state and warrants the
same approval gate as the deploy itself. Database migrations may need their own rollback path —
check before deploying, not after.
