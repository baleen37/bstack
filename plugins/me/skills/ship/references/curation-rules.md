# Curation Rules

Risk classification and default task sets for `/ship`. Used at CLASSIFY and PLAN phases.

## Classes

### low

Criteria — ALL must hold:
- no user-facing runtime behavior change OR change limited to <10 internal users
- no money, auth, permissions, or data integrity touched
- trivially revertible (single commit `git revert`)
- no DB migration, no schema change, no new external dependency

Examples:
- README/docs typo, comment fixes
- internal admin UI additive elements (filter dropdown, column toggle)
- dev tool changes that don't affect production
- test-only changes

### standard

Default class when not clearly low or risky. Criteria — any one is enough:
- user-facing feature or copy change
- public API surface change (new endpoint, new field, behavior change)
- new external dependency
- observable performance characteristic change

Examples:
- new feature for end users
- new public REST/GraphQL endpoint
- changing default values, copy, or layout for users
- adding a third-party SDK

### risky

Criteria — any one triggers risky:
- payment, billing, or money flow
- authentication, authorization, session, permissions
- data migration, schema change, irreversible writes
- broad blast radius (>50% of users, core flow)
- security-sensitive change
- deadline pressure on a non-trivial change

Examples:
- adding fields to checkout
- changing how sessions are stored
- migrating users to a new table
- modifying rate limiting on auth endpoints

If between classes, pick the higher one. "Conditionally" thinking belongs here, not in classification.

## Default task sets

Each class has a baseline task set. Add change-specific tasks discovered during SCOPE (DB migration, new env var, etc.).

### low (3 tasks)

1. Confirm scope from diff matches user description
2. Confirm a one-line revert path exists (commit hash to revert)
3. Merge — no further launch ceremony required

### standard (8 tasks)

1. Confirm scope from diff matches user description
2. `/qa` evidence present and passing for the changed paths
3. Identify rollback path (revert command or feature flag off)
4. Identify one success signal to watch (metric, log, dashboard)
5. Identify one failure signal to watch (error rate, alert)
6. If user-facing: behind a feature flag OR justified why not
7. Deploy to staging and verify smoke flow
8. Deploy to production; monitor watch window for first hour

### risky (full playbook)

Use full `launch-playbook.md`. Minimum task set:

1. Confirm scope from diff matches user description
2. `/qa` evidence present for changed paths AND adjacent critical paths
3. Pre-launch checklist (security, performance, accessibility, infra) — section by section
4. Feature flag in place; OFF by default
5. Rollback plan written: trigger conditions, steps, time-to-rollback
6. Monitoring watchpoints defined: error rate baseline, P95 latency baseline, business metric
7. Deploy to staging; full smoke test
8. Deploy to production with flag OFF; verify health
9. Enable for team only; 24h watch
10. Canary 5% with rollout decision thresholds (advance/hold/rollback)
11. Gradual increase 25% → 50% → 100% with monitoring at each step
12. Watch window 1 week after 100%
13. Feature flag cleanup with owner and date

## Adding change-specific tasks

During SCOPE, look for these and add tasks:

| Found in diff | Add task |
|---|---|
| New `migrations/` file | Verify migration is reversible OR document why not |
| New `process.env.X` reference | Confirm env var set in production |
| New entry in `package.json` dependencies | `npm audit` shows no high/critical |
| New public route/handler | Rate limiting decision |
| Auth/session change | Session invalidation plan |
| Removed code path | Confirm no callers (grep), confirm not in feature flags |

## When to refuse classification

If the user has not provided a one-line description AND the diff is empty or unreadable, refuse to classify. Run SCOPE again or stop.

If the change spans multiple unrelated concerns (e.g., auth fix + UI tweak + new feature), ask the user to split before shipping. Do not classify a mixed change.
