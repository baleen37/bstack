---
name: ci-cd-and-automation
description: Shift Left, Faster is Safer, feature flags, quality gate pipelines, and failure feedback loops. Use when setting up or modifying build and deploy pipelines.
---

# CI/CD and Automation

## Overview

Pipelines are the safety net. Push checks left (run early, run cheap), keep feedback fast, and automate the boring parts so humans review only what matters.

## Core Principles

- **Shift Left**: catch defects at the earliest stage — lint and type-check before tests, tests before integration, integration before deploy.
- **Faster is Safer**: short pipelines = frequent deploys = small blast radius. A 5-minute pipeline beats a 50-minute one.
- **Quality Gates**: each stage is a gate. Failures block progression; flakes get fixed, not retried.
- **Feature Flags**: decouple deploy from release. Ship dark, flip on demand.
- **Feedback Loops**: failures must reach the author within minutes, with actionable signal.

## Pipeline Layers

1. **Pre-commit**: format, lint, basic checks (seconds).
2. **CI**: build, unit tests, type checks (minutes).
3. **Integration**: e2e, smoke tests against a staging-like env.
4. **Deploy**: staged rollout, canary, full.
5. **Post-deploy**: health checks, monitoring, automated rollback triggers.

## Anti-patterns

- Slow pipelines that batch many changes — increases blast radius and debug cost.
- Flaky tests retried instead of fixed.
- Manual deploy steps that "only one person knows".
- Feature flags that never get cleaned up.
