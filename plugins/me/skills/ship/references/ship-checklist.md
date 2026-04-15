# Ship Checklist

Reference material for `/ship`. Read this when you need concrete examples while assessing shipping readiness. This file supports the core skill; it does not change the `/ship` contract.

## Pre-launch checks

Use these to decide whether the change is basically ready to leave the branch:

- The change scope can be described in one or two sentences.
- The relevant tests or verification steps are named and have recent evidence.
- Any required review, approval, or human sign-off is explicit.
- Any launch notes or operator context are written down somewhere discoverable.

## Rollout readiness

Use these to assess whether the release can be introduced safely:

- A staged rollout is possible, or the change is clearly low-risk enough not to need one.
- A feature flag, kill switch, or config gate exists when exposure risk is meaningful.
- The change does not require an all-at-once cutover without justification.

## Rollback readiness

Use these to assess whether the team can recover quickly:

- A rollback path can be explained in plain language.
- Irreversible schema or data changes are identified explicitly.
- The first action to take during a bad launch is known.

## Monitoring readiness

Use these to assess whether post-launch behavior is observable:

- There is at least one success signal to watch.
- There is at least one failure signal to watch.
- The relevant logs, metrics, or alerts are named.
- The launch is not blind; someone could tell within minutes if it went wrong.

## Blocking issue examples

These usually mean `/ship` should report **Not ready**:

- No test or verification evidence is available.
- No rollback path can be described.
- Monitoring signals are completely unknown.
- Required QA or review has clearly not happened.

## Warning examples

These usually mean `/ship` should report **Conditionally ready** rather than **Ready**:

- The change is large and rollout strategy is weak.
- A feature flag would help but is not strictly required.
- Monitoring exists but the exact watchpoints are not written down.
- The launch can proceed, but only with explicit human attention.

## Suggested decision language

Use short, direct language:

- **Ready** — No blockers found. Basic rollout, rollback, and monitoring expectations are covered.
- **Conditionally ready** — No hard blocker, but the ship needs explicit follow-up before or during launch.
- **Not ready** — One or more critical gates are missing; shipping now would be unsafe.
