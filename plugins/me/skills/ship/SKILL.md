---
name: ship
description: >-
  Use when preparing to deploy to production, asked to "ship", "release", or "deploy", or when
  you need to verify a deploy succeeded or plan a rollback. Covers the full flow: pre-deploy
  checks, the deploy itself, and post-deploy verification with rollback on failure.
---

# Ship

Use one closed workflow: **scope changed behavior → define its evidence → deploy →
wait for completion → verify each changed behavior → check unaffected critical behavior**.
Don't skip phases.

How a project deploys, how to tell a deploy finished, and how to roll back are all
project-specific. Discover them; never assume or invent them.

## Phase 1 — Pre-deploy

1. **Scope** — what changed, what production systems it touches, and every behavior changed
   by the deploy. Include user-visible behavior, integration boundaries, deferred effects, and
   durable-state changes when applicable.
   Before declaring `GO`, create one provisional verification-matrix row per changed behavior:
   the production-safe check, expected observable result, and evidence to collect. Phase 3
   completes these same rows. If a changed behavior has no viable check, stop and show the gap
   before deployment.
   Ask what this repo actually ships: if the changed files are its release artifact, the
   change is deployable regardless of file type. Only when nothing reaches production →
   say "Non-deployable change, skipping deploy/verify phases" and stop after the normal
   commit/PR flow.

2. **Find how this project deploys.** Read both project docs (CLAUDE.md, AGENTS.md, README,
   any deploy guide) and CI/CD config before concluding, then deploy config files, then ask
   the user. Determine:
   - What triggers a deploy. Merging to the default branch is a valid trigger; a project
     with no manual deploy command is normal, not blocked.
   - How to tell the deploy finished.
   - How to read the deployed version or commit.
   - How to roll back.

   In a monorepo, scope discovery to the changed paths — there may be one pipeline per
   service. Track where each of the four answers came from; you report that below.
   Only when a deploy is required and no trigger can be established: `BLOCKED`.

3. **Check reversibility.** Scan the diff for anything that changes persistent state, not
   just code. Record `rollback-safe`, `partial`, or `fix-forward-only` now. Deciding this
   during an incident is deciding it badly.

   `partial` is the common case: the parts revert independently, so name which part rolls
   back and which one stays. A single verdict covering the whole change will be wrong about
   one half of it.

4. **Verify readiness** — CI green, checks passing. Use the project's own commands.

5. **Report** — four parts, in order:
   - **Verdict** — GO or NO-GO, with the reversibility verdict from step 3. When the
     verdict is `partial`, name which part rolls back and which part stays.
   - **Rollback plan** — the procedure, or `undocumented` when the project has none.
   - **Discovery** — each of the four answers with where you found it. Mark any you
     inferred rather than read as `inferred`.
   - **Validation plan** — the provisional verification matrix, with one row for every
     changed behavior.
   - **Undocumented** — every answer that was `undocumented` or `inferred`, as a list.
     Empty list when the project documented all four. When the list is non-empty, ask
     the user whether to write those answers into the project's docs before continuing.

   Stop and show evidence if anything is `BLOCKED`.

## Phase 2 — Deploy

Trigger the deploy the way this project does it. **`NEEDS_APPROVAL`** — never without the
user's explicit go-ahead.

## Phase 3 — Post-deploy

Run in order. The order matters.

1. **Did the deploy finish?** When a deploy rolls out gradually, old and new both serve
   traffic, so verifying early tests whichever answers first. Wait for the project's
   completion signal before continuing.

2. **Is the deployed artifact mine?** A health check returns 200 from the old version too,
   so this is the step that proves the new code is live. Compare the live version/commit
   against what you deployed. A mismatch means the deploy did not take effect — treat as
   failure. When nothing can report it, say so and note the gap.

3. **Verify every changed behavior.** Build a **Verification matrix** from Phase 1 before
   running checks:

   | Changed behavior | Production-safe check | Expected observable result | Evidence | Outcome |
   | --- | --- | --- | --- | --- |

   For every behavior changed by the deploy, run a check that takes the changed path and
   assert its changed observable result: visible output, rendered state, durable state, emitted
   signal, or other relevant effect. A health check, a matching version, or an unrelated check
   does not cover a row. For a changed user journey, walk its primary path.

   An untested changed behavior is not a successful deploy. Report it as `GAP` with the
   reason and the safe check needed; do not report an overall verification success until
   every row is `OK`.

4. **Check unaffected critical behavior.** Run the project's baseline availability check, then
   one unchanged critical path that exercises its real dependencies when the change could affect
   it.

Report each `OK` with evidence (status code, version string, log excerpt, screenshot path)
or `FAIL` with the exact failing output. No success claims without evidence.

## On failure

1. Collect evidence.
2. Choose from the Phase 1 reversibility verdict: `rollback-safe` → roll back.
   `fix-forward-only` → rolling back is itself destructive, so fix forward.
   `partial` → roll back only the part you recorded as reversible, and say what you are
   deliberately leaving in place.
3. Present the command as `NEEDS_APPROVAL` with reasoning. When no rollback procedure was
   documented, redeploying the previous known-good version is the usual path — propose it
   as your reading of this project's setup, not as an established procedure.

**Never auto-rollback.** Rollback changes production state and needs the same approval gate
as the deploy.

## Decision labels

- `AUTO-COMPLETED` — safe read-only checks and local drafts, done with evidence.
- `NEEDS_APPROVAL` — anything changing shared or external state: pushes, merges, releases,
  deploys, infra/flag/config/secret/DB changes, external notifications, rollbacks.
- `BLOCKED` — failing checks, no way to trigger the deploy, unverifiable production impact.
  An undocumented rollback path is a gap to report, not a blocker.
