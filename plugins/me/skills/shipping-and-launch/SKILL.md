---
name: shipping-and-launch
description: Pre-launch checklists, feature flag lifecycle, staged rollouts, rollback procedures, and monitoring setup. Use when preparing to deploy to production.
---

# Shipping and Launch

## Overview

Every launch should be reversible, observable, and incremental. The goal is not "deployed" — it's "deployed safely with a way out."

## Pre-Launch Checklist

- [ ] Feature flag in place, default off.
- [ ] Monitoring: dashboards exist for the new code path.
- [ ] Alerts: SLO-based, not noise.
- [ ] Rollback plan: documented, tested, one command.
- [ ] Load expectations: known and tested.
- [ ] Data migrations: backward-compatible or gated.
- [ ] On-call aware: owner identified, escalation path clear.
- [ ] Success criteria: defined before launch, measurable.

## Feature Flag Lifecycle

1. **Create**: default off, gated to internal users.
2. **Internal**: dogfood, watch metrics.
3. **Canary**: 1% → 10% → 50% with health checks at each step.
4. **Full**: 100%.
5. **Cleanup**: remove the flag and dead branch within one release after 100%.

A flag stuck at 100% for months is a bug.

## Staged Rollout

- Start small enough that a failure is recoverable.
- Define "promote" criteria: error rate, latency, business metrics.
- Define "halt" criteria: same metrics, hard thresholds.
- Bake time between stages — hours, not minutes — to catch slow-burn issues.

## Rollback Procedure

- Must be one command or one flag flip.
- Must not require a deploy.
- Must be tested before launch, not during the incident.
- Data changes need a forward-compatible rollback (no destructive migrations during a launch).

## Monitoring Setup

- **Golden signals**: latency, traffic, errors, saturation.
- **Business metrics**: did the feature actually do what we wanted?
- **Comparison**: new path vs old path side-by-side during rollout.

## Post-Launch

- Hold review within a week: what worked, what surprised, what to change next time.
- Schedule flag cleanup explicitly — it does not happen on its own.

## Anti-patterns

- Deploying on Friday afternoon.
- "We'll add monitoring after launch."
- Rollback plans that require a code change.
- Flags that outlive the launch by quarters.
