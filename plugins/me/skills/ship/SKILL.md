---
name: ship
description: >-
  Run the pre-launch checklist via parallel fan-out to specialist personas, then synthesize a go/no-go decision with a
  rollback plan. Use when asked to "ship", "release", "deploy", or "is this ready to go live?".
disable-model-invocation: true
---

<!-- Adapted from https://github.com/addyosmani/agent-skills/blob/main/.claude/commands/ship.md -->

# /ship: parallel fan-out launch review

`/ship` is a **fan-out orchestrator**. It runs three specialist personas in parallel against the current change,
then merges their reports into a single go/no-go decision with a rollback plan. The personas operate independently —
no shared state, no ordering — which is what makes parallel execution safe and useful here.

For the underlying pre-launch checklists, see the `shipping-and-launch` skill. That includes security, performance,
accessibility, CI/check status, migrations/config/env readiness, feature flag lifecycle, staged rollout, monitoring and
alerts, documentation, post-launch verification, and rollback procedure.

## Phase A — Parallel fan-out

For non-trivial production-bound changes, spawn three subagents concurrently using the Agent tool. **Issue all three
Agent tool calls in a single assistant turn** so they execute in parallel — sequential calls defeat the purpose of this
skill.

In Claude Code, each call passes `subagent_type` matching the persona's `name` field:

1. **`code-reviewer`** — Run a five-axis review: correctness, readability, architecture, security, and performance.
   Output the standard review template.
2. **`security-auditor`** — Run a vulnerability and threat-model pass. Check OWASP Top 10, secrets handling,
   auth/authz, and dependency CVEs. Output the standard audit report.
3. **`test-engineer`** — Analyze test coverage for the change. Identify gaps in happy path, edge cases, error paths,
   and concurrency scenarios. Output the standard coverage analysis.

In other harnesses without an Agent tool, invoke each persona's system prompt sequentially and treat their outputs as if
returned in parallel — the merge phase still works.

Constraints (from Claude Code's subagent model):

- Subagents cannot spawn other subagents — do not let one persona delegate to another.
- Each subagent gets its own context window and returns only its report to this main session.
- If a persona is not installed in the current environment, fall back to running that persona's pass yourself in the
  main context and label the section accordingly. Do not silently skip it.

**Persona resolution.** This plugin includes default `code-reviewer`, `security-auditor`, and `test-engineer` personas.
If you've defined your own versions in `.claude/agents/` or `~/.claude/agents/`, those take precedence — `/ship` picks
up your customizations automatically. This is intentional: plugin subagents sit at the bottom of Claude Code's scope
priority table, so user-level definitions win by design.

## Phase B — Merge in main context

Once all three reports are back, the main agent (not a sub-persona) synthesizes them:

1. **Code Quality** — Aggregate Critical/Important findings from `code-reviewer` and any failing tests, lint, build, or
   CI/check output. Resolve duplicates between reviewers.
2. **Security** — Promote any Critical/High `security-auditor` findings to launch blockers. Cross-reference with
   `code-reviewer`'s security axis.
3. **Performance** — Pull from `code-reviewer`'s performance axis; cross-check Core Web Vitals if applicable.
4. **Accessibility** — Verify keyboard nav, screen reader support, and contrast directly or with the accessibility
   checklist.
5. **Infrastructure** — Verify CI/checks, migrations, config/env, feature flags, monitoring/alerts, staged rollout, and
   rollback triggers/procedure directly.
6. **Documentation** — Verify README, ADRs, changelog, runbooks, and post-launch verification steps directly.

## Phase C — Decision and rollback

Produce a single output:

```markdown
## Ship Decision: GO | NO-GO

### Blockers (must fix before ship)
- [Source persona: Critical finding + file:line]

### Recommended fixes (should fix before ship)
- [Source persona: Important finding + file:line]

### Acknowledged risks (shipping anyway)
- [Risk + mitigation]

### Observability and rollout
- Monitoring/alerts: [dashboards, alerts, owners]
- Staged rollout: [flag/ramp plan and stop criteria]
- Post-launch verification: [checks to run after release]

### Rollback plan
- Trigger conditions: [metrics, alerts, logs, or user-impact signals that prompt rollback]
- Rollback procedure: [exact steps and owner]
- Recovery time objective: [target]

### Specialist reports (full)
- [code-reviewer report]
- [security-auditor report]
- [test-engineer report]
```

## Rules

1. The three Phase A personas run in parallel — never sequentially.
2. Personas do not call each other. The main agent merges in Phase B.
3. The rollback plan is mandatory before any GO decision, including rollback trigger and procedure.
4. Default to NO-GO for any Critical security finding, failing required test/build/check/CI status, missing rollback
   plan, or unverifiable production risk. Only override if the user explicitly accepts the risk.
5. A GO decision must include observability coverage, monitoring/alert ownership, staged rollout or feature-flag plan,
   and post-launch verification steps.
6. **Skip the fan-out only if all of the following are true:** the change touches 2 files or fewer, the diff is under
   50 lines, and it does not touch auth, payments, data access, or config/env. Otherwise, default to fan-out. `/ship`
   is designed for production-bound changes — when the blast radius is non-trivial, run the parallel `code-reviewer`,
   `security-auditor`, and `test-engineer` review even if the diff looks small.
