---
name: ship
description: >-
  Use when preparing to deploy to production, asked to "ship", "release", or
  "deploy", or when you need to verify a deploy succeeded or plan a rollback.
  Covers project-specific promotion, pre-deploy checks, deployment, and
  post-deploy verification.
---

# Ship

Use one closed workflow: **scope changed behavior → resolve the project's
promotion route → define its evidence → deploy → wait for completion → verify
each changed behavior → check unaffected critical behavior**.

How a project promotes changes, how to tell a deploy finished, and how to roll
back are project-specific. Discover them from repository evidence. Never assume
or invent them.

## Phase 1: Pre-deploy

1. **Scope** — identify what changed, which production systems it touches, and
   every behavior changed by the deploy. Include user-visible behavior,
   integration boundaries, deferred effects, and durable-state changes when
   applicable.

   Before declaring `GO`, create one provisional verification-matrix row per
   changed behavior: the production-safe check, expected observable result, and
   evidence to collect. Phase 3 completes these same rows. If a changed
   behavior has no viable check, stop and show the gap before deployment.

   If the changed files are the project's release artifact, the change is
   deployable regardless of file type. Only when nothing reaches production,
   report `Non-deployable change`, skip deploy and verify phases, and continue
   with the normal PR flow.

2. **Resolve the promotion route before any action** — read the applicable
   project instructions and release surfaces:

   - `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `local.md`, `README`,
     `CONTRIBUTING`, and release/deploy docs;
   - CI/CD workflows, deploy scripts, release configuration, and branch or
     environment filters;
   - hosting metadata when available, including protected branches, required
     checks, existing PR bases, and deployment environments.

   Record the result:

   ```text
   Release route:
     source: <current branch>
     next PR/merge base: <branch, environment, or none>
     required order: <promotion steps>
     final target: <environment and/or branch>
     deploy trigger: <documented trigger or none>
     evidence: <file:line, workflow trigger, or command output>
   ```

   The phrase `ship to prod` names an outcome. It does not choose a branch or
   authorize a direct production merge. Use the names and order found in the
   project evidence.

   - If an intermediate branch or environment is required, prepare only the
     next step.
   - A local merge or rebase only synchronizes a working branch. It does not
     prove that a PR landed in the integration branch.
   - Use the project's documented synchronization method. Skip local sync when
     the project does not require it.
   - If the route is missing, conflicting, or not provable, stop as `BLOCKED`
     before fetch, merge, push, PR creation, or deploy.
   - After an intermediate merge, verify the merged PR and required post-merge
     jobs, then resolve the route again from the updated state.

3. **Find how this project deploys.** Determine:

   - what triggers a deploy;
   - how to tell the deploy finished;
   - how to read the deployed version or commit;
   - how to roll back.

   A merge to an integration branch is a valid deploy trigger when the project
   documents it. A project with no manual deploy command is normal, not blocked.
   In a monorepo, scope discovery to the changed paths because each service may
   have a different pipeline. Track where each answer came from.

   Only when a deploy is required and no trigger can be established: `BLOCKED`.

4. **Check reversibility.** Scan the diff for persistent-state changes, not just
   code. Record `rollback-safe`, `partial`, or `fix-forward-only` now.

   For `partial`, name which part rolls back and which part stays. A single
   verdict for the whole change can be wrong about one half of it.

5. **Verify readiness** — CI green and project-required checks passing. Use the
   project's own commands.

6. **Report** in this order:

   - Verdict: `GO` or `NO-GO`, including reversibility;
   - Rollback plan, or `undocumented`;
   - Discovery: the four deployment answers and their sources, marking inferred
     answers as `inferred`;
   - Validation plan: the provisional verification matrix;
   - Undocumented: every undocumented or inferred answer.

   If the undocumented list is non-empty, ask whether to record those answers
   in the project's documentation before continuing. Stop and show evidence if
   anything is `BLOCKED`.

## Phase 2: Deploy

Trigger the deploy using the route and trigger discovered in Phase 1.

Anything that changes shared or external state is `NEEDS_APPROVAL`, including
pushes, merges, releases, deploys, rollbacks, and external notifications. Never
perform those actions without the user's explicit go-ahead.

When handing off PR work, pass the route's immediate next base and final target
separately. Create or merge directly to the final production target only when
the project explicitly documents that route and its checks and approvals are
satisfied.

## Phase 3: Post-deploy

Run these checks in order:

1. **Did the deploy finish?** For gradual rollouts, wait for the project's
   completion signal before continuing.
2. **Is the deployed artifact mine?** Compare the live version or commit against
   what was deployed. A health check alone is insufficient.
3. **Verify every changed behavior.** Complete the matrix from Phase 1:

   | Changed behavior | Production-safe check | Expected observable result | Evidence | Outcome |
   | --- | --- | --- | --- | --- |

   Run a check through the changed path and assert its changed observable result.
   Health, version, or unrelated checks do not cover a row. An untested changed
   behavior is a `GAP`, not a successful deploy.
4. **Check unaffected critical behavior.** Run the project's baseline
   availability check and one unchanged critical path when the change could
   affect it.

Report every `OK` with evidence such as a status code, version string, log
excerpt, screenshot path, or observable result. Report `FAIL` with the exact
output. Do not claim overall verification success while any matrix row is a
`GAP`.

## On failure

1. Collect evidence.
2. Follow the Phase 1 reversibility verdict:
   - `rollback-safe`: roll back after approval;
   - `fix-forward-only`: do not roll back, fix forward;
   - `partial`: roll back only the recorded reversible part.
3. Present the command as `NEEDS_APPROVAL` with reasoning. If rollback is
   undocumented, propose redeploying the previous known-good version as an
   inference, not as an established procedure.

Never auto-rollback. Rollback changes production state and needs the same
approval gate as deployment.

## Decision labels

- `AUTO-COMPLETED` — safe read-only checks and local drafts completed with
  evidence;
- `NEEDS_APPROVAL` — shared or external state would change;
- `BLOCKED` — checks fail, no deploy trigger exists, the route is unknown, or
  production impact cannot be verified.
