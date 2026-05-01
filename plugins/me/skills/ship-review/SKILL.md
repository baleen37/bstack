---
name: ship-review
description: Explicit-only fan-out review. Run ONLY when the user explicitly invokes /ship-review. Spawns code-reviewer, security-auditor, and test-engineer subagents in parallel against the current change, then merges into a single GO/NO-GO decision with a rollback plan. Do NOT auto-trigger from words like "ship", "release", or "deploy" — those keywords are reserved for the /ship skill.
---

<!-- Adapted from https://github.com/addyosmani/agent-skills/blob/main/.claude/commands/ship.md -->

# /ship-review: parallel fan-out launch review

This skill is **explicit-invocation only**. Run it when, and only when, the user types `/ship-review` (or unambiguously asks you to "run ship-review"). Do not invoke it implicitly from related words like "ship", "release", "deploy", or "launch" — those belong to the `/ship` skill.

`/ship-review` is a **fan-out orchestrator**. It runs three specialist personas in parallel against the current change, then merges their reports into a single go/no-go decision with a rollback plan. The personas operate independently — no shared state, no ordering — which is what makes parallel execution safe and useful here.

## Phase A — Parallel fan-out

Spawn three subagents concurrently using the Agent tool. **Issue all three Agent tool calls in a single assistant turn so they execute in parallel** — sequential calls defeat the purpose of this skill.

Each call passes `subagent_type` matching the persona's `name` field:

1. **`code-reviewer`** — Run a five-axis review (correctness, readability, architecture, security, performance) on the staged changes or recent commits. Output the standard review template.
2. **`security-auditor`** — Run a vulnerability and threat-model pass. Check OWASP Top 10, secrets handling, auth/authz, dependency CVEs. Output the standard audit report.
3. **`test-engineer`** — Analyze test coverage for the change. Identify gaps in happy path, edge cases, error paths, and concurrency scenarios. Output the standard coverage analysis.

Constraints (from Claude Code's subagent model):

- Subagents cannot spawn other subagents — do not let one persona delegate to another.
- Each subagent gets its own context window and returns only its report to this main session.
- If a persona is not installed in the current environment (e.g., no `security-auditor` agent registered), fall back to running that persona's pass yourself in the main context and label the section accordingly. Do not silently skip it.

**Persona resolution.** If the user has defined their own `code-reviewer`, `security-auditor`, or `test-engineer` in `.claude/agents/` or `~/.claude/agents/`, those take precedence. User-level definitions win over plugin definitions by design.

## Phase B — Merge in main context

Once all three reports are back, the main agent (not a sub-persona) synthesizes them:

1. **Code Quality** — Aggregate Critical/Important findings from `code-reviewer` and any failing tests, lint, or build output. Resolve duplicates between reviewers.
2. **Security** — Promote any Critical/High `security-auditor` findings to launch blockers. Cross-reference with `code-reviewer`'s security axis.
3. **Performance** — Pull from `code-reviewer`'s performance axis; cross-check Core Web Vitals if applicable.
4. **Accessibility** — Verify keyboard nav, screen reader support, contrast (not covered by the three personas — handle directly here).
5. **Infrastructure** — Env vars, migrations, monitoring, feature flags. Verify directly.
6. **Documentation** — README, ADRs, changelog. Verify directly.

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

### Rollback plan
- Trigger conditions: [what signals would prompt rollback]
- Rollback procedure: [exact steps]
- Recovery time objective: [target]

### Specialist reports (full)
- [code-reviewer report]
- [security-auditor report]
- [test-engineer report]
```

## Rules

1. **Explicit invocation only.** Do not auto-trigger this skill from related vocabulary. If the user says "ship it" or "let's release", do not run `/ship-review` unless they actually named it.
2. The three Phase A personas run in parallel — never sequentially.
3. Personas do not call each other. The main agent merges in Phase B.
4. The rollback plan is mandatory before any GO decision.
5. If any persona returns a Critical finding, the default verdict is NO-GO unless the user explicitly accepts the risk.
6. **Always run the full fan-out.** Do not skip personas based on diff size — the user already opted in by naming the skill.
