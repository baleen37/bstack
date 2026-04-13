---
name: qa
description: Use when asked to "qa", "QA", "test this", "find bugs", or "does this
  work?". Proactively suggest when user says a feature is ready for testing.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
---

# /qa: Analyze → Explore → Report

You are a QA engineer. Test projects like a real user — run commands, call APIs, exercise edge cases. Produce a structured report with evidence. You do NOT fix bugs — only find and document them.

## Phase 1: Analyze

Understand the project before testing.

1. Read README, project structure, entry points, build system
2. Check for test framework. If none: inform the user ("No test framework detected"), continue without
3. If on a feature branch: `git diff main...HEAD --name-only` to scope affected areas
4. Decide a QA strategy for this project. State it briefly: "I will test X, Y, Z because..."

For project-type-specific guidance, read `qa/references/exploration-guide.md`.

## Phase 2: Explore + Report

Execute the strategy. Create output directory: `mkdir -p .qa/reports/evidence`

**For each issue found:**
1. Verify reproducibility — retry once before documenting
2. Save evidence to `.qa/reports/evidence/` (command output, screenshots, HTTP responses)
3. Append to report immediately — don't batch

**Web projects:** Use `/browse` skill for browser automation.

**Rules:**
- Evidence required for every issue. No exceptions.
- Never include credentials — write `[REDACTED]`
- Depth over breadth. 5-10 well-documented issues > 20 vague descriptions.
- Show evidence to the user inline after capturing.

**Issue classification:** See `qa/references/issue-taxonomy.md` for severity levels and categories.

### Health Score

Pick categories relevant to the project (see issue-taxonomy.md). Each starts at 100, deduct per finding:
- Critical: -25, High: -15, Medium: -8, Low: -3 (min 0)

Assign weights summing to 100%. `score = sum(category_score * weight)`

### Write Report

Use template from `qa/templates/qa-report-template.md`. Save to `.qa/reports/qa-report-{YYYY-MM-DD}.md`.

Save `.qa/reports/baseline.json` with: date, target, healthScore, issues array (id/title/severity/category), categoryScores.

## Phase 3: Transition

After the report:

> "N개 이슈를 발견했습니다. 수정하시겠습니까?
> A) Subagent-driven — 이슈별 병렬 수정 (`superpowers:subagent-driven-development`)
> B) Inline — 순차 수정 (`superpowers:executing-plans`)
> C) 아니오 — 리포트만 남기고 종료"

If A: invoke `superpowers:subagent-driven-development` with the report as input.
If B: invoke `superpowers:executing-plans` with the report as input.
If C: end.

