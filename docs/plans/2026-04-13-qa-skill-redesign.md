# QA Skill Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `/qa` skill as a lean, project-agnostic explore+report tool (~80 lines SKILL.md) with heavy content in references.

**Architecture:** Replace the current 390-line monolithic SKILL.md with a slim core (flow + rules + health score + transition) and two reference files loaded on demand. Extract exploration checklists from SKILL.md and issue-taxonomy.md into a new `exploration-guide.md`. Simplify the report template to remove fix-related sections.

**Tech Stack:** Markdown (skill authoring), no runtime dependencies

---

### Task 1: Create `references/exploration-guide.md`

Extract project-type exploration content from current SKILL.md (lines 181-224: Web/CLI/API/Library sections) and current issue-taxonomy.md (lines 65-117: Exploration Checklists) into a new reference file.

**Files:**
- Create: `plugins/me/skills/qa/references/exploration-guide.md`

- [ ] **Step 1: Write the exploration guide**

Create `plugins/me/skills/qa/references/exploration-guide.md` with this content:

```markdown
# Exploration Guide

Reference material for QA exploration. Read this when you need project-type-specific guidance during the Explore phase. These are suggestions, not mandatory checklists — adapt to the project.

## Web Applications

For each page visited:

1. **Visual scan** — Look for layout issues, broken images, alignment
2. **Interactive elements** — Click every button, link, and control
3. **Forms** — Fill and submit. Test empty submission, invalid data, edge cases
4. **Navigation** — Check all paths in/out. Breadcrumbs, back button, deep links
5. **States** — Check empty state, loading state, error state, overflow state
6. **Console** — Check for JS errors or failed network requests after interactions
7. **Responsiveness** — Check mobile and tablet viewports if relevant
8. **Auth boundaries** — What happens when logged out? Different user roles?

**Framework hints:**
- Next.js: hydration errors, `_next/data` 404s, client-side navigation
- Rails: N+1 warnings, CSRF tokens, Turbo/Stimulus integration
- SPA: stale state, back/forward history, client-side routes

**Browser testing:** Use `/browse` skill for browser automation.

## CLI Tools

For each command/subcommand:

1. **Help text** — Does `--help` exist? Is it accurate and complete?
2. **Happy path** — Run with typical inputs. Correct output?
3. **Invalid inputs** — Wrong types, missing required args, unknown flags. Clear error messages?
4. **Edge cases** — Empty input, huge input, special characters, piped input, no TTY
5. **Exit codes** — 0 on success, non-zero on failure? Consistent?
6. **stderr vs stdout** — Errors go to stderr? Output is parseable?
7. **Combinations** — Do flags interact correctly? Conflicting flags handled?
8. **Idempotency** — Run the same command twice. Same result?

## API Servers

For each endpoint:

1. **Happy path** — Valid request, correct response code and body
2. **Validation** — Missing fields, wrong types, boundary values. Proper 4xx responses?
3. **Auth** — Request without token, expired token, wrong role. Proper 401/403?
4. **Error responses** — Consistent format? Useful error messages? No stack traces leaked?
5. **Idempotency** — POST twice, PUT twice. Expected behavior?
6. **Content negotiation** — Correct Content-Type headers?
7. **Edge cases** — Large payloads, empty bodies, unicode, special characters
8. **Spec compliance** — If OpenAPI/Swagger exists, does the endpoint match?

## Libraries

For each public API surface:

1. **Test suite** — Run all tests. Note failures, slow tests, flaky tests
2. **Coverage gaps** — Are there exported functions with no tests?
3. **Error messages** — When misused, are errors clear and actionable?
4. **Type safety** — Do types match runtime behavior?
5. **Edge cases** — Boundary values, null/undefined, empty collections
6. **Documentation** — Do README examples actually work?

## Other Project Types

For projects that don't fit the above (infra, data pipelines, mobile, etc.):

1. **Identify entry points** — What are the primary interfaces?
2. **Run existing tests** — Execute whatever test suite exists
3. **Exercise main flows** — Test the primary use cases end-to-end
4. **Check error handling** — What happens when things go wrong?
5. **Review configuration** — Are defaults sensible? Are required configs documented?
```

- [ ] **Step 2: Verify file exists and is well-formed**

Run: `wc -l plugins/me/skills/qa/references/exploration-guide.md && head -3 plugins/me/skills/qa/references/exploration-guide.md`
Expected: ~60 lines, starts with `# Exploration Guide`

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/qa/references/exploration-guide.md
git commit -m "feat(qa): add exploration-guide.md reference file"
```

---

### Task 2: Slim down `references/issue-taxonomy.md`

Remove the "Exploration Checklists" section (now in exploration-guide.md). Keep only severity levels and category definitions.

**Files:**
- Modify: `plugins/me/skills/qa/references/issue-taxonomy.md` (remove lines 65-117)

- [ ] **Step 1: Remove Exploration Checklists section**

Edit `plugins/me/skills/qa/references/issue-taxonomy.md`: delete everything from `## Exploration Checklists` (line 65) to end of file (line 117). The file should end after the `### 7. Documentation` section.

- [ ] **Step 2: Verify**

Run: `wc -l plugins/me/skills/qa/references/issue-taxonomy.md && tail -5 plugins/me/skills/qa/references/issue-taxonomy.md`
Expected: ~63 lines, ends with Documentation category content

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/qa/references/issue-taxonomy.md
git commit -m "refactor(qa): move exploration checklists to exploration-guide.md"
```

---

### Task 3: Simplify `templates/qa-report-template.md`

Remove fix-related sections (Fixes Applied, Before/After Evidence, Regression Tests, Regression comparison) and the fix-related fields from Ship Readiness.

**Files:**
- Modify: `plugins/me/skills/qa/templates/qa-report-template.md`

- [ ] **Step 1: Rewrite the template**

Replace entire content of `plugins/me/skills/qa/templates/qa-report-template.md` with:

```markdown
# QA Report: {PROJECT_NAME}

| Field | Value |
|-------|-------|
| **Date** | {DATE} |
| **Target** | {what was tested} |
| **Branch** | {BRANCH} |
| **Commit** | {COMMIT_SHA} |
| **Scope** | {SCOPE or "Full project"} |
| **Duration** | {DURATION} |

## Health Score: {SCORE}/100

| Category | Weight | Score |
|----------|--------|-------|
| {category} | {weight}% | {0-100} |

## Top Issues

1. **ISSUE-NNN: {title}** — {one-line description}

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| **Total** | **0** |

## Issues

### ISSUE-001: {Short title}

| Field | Value |
|-------|-------|
| **Severity** | critical / high / medium / low |
| **Category** | {category} |
| **Location** | {where the issue was found} |

**Description:** {What is wrong, expected vs actual.}

**Repro Steps:**

1. {Action}
2. **Observe:** {what goes wrong}

**Evidence:** {link to evidence file or inline quote}
```

- [ ] **Step 2: Verify**

Run: `wc -l plugins/me/skills/qa/templates/qa-report-template.md`
Expected: ~45 lines (down from 102)

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/qa/templates/qa-report-template.md
git commit -m "refactor(qa): simplify report template, remove fix sections"
```

---

### Task 4: Rewrite `SKILL.md`

Replace the entire 390-line SKILL.md with a lean ~80-line version covering: frontmatter, 3-phase flow, rules, health score, transition.

**Files:**
- Modify: `plugins/me/skills/qa/SKILL.md`

- [ ] **Step 1: Rewrite SKILL.md**

Replace entire content of `plugins/me/skills/qa/SKILL.md` with:

```markdown
---
name: qa
description: Use when asked to "qa", "QA", "test this", or "find bugs". Proactively
  suggest when user says a feature is ready for testing or asks "does this work?".
  Explores a project like a real user, produces a structured report with health scores
  and evidence.
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

Save `baseline.json`:
```json
{
  "date": "YYYY-MM-DD",
  "target": "<what was tested>",
  "healthScore": N,
  "issues": [{ "id": "ISSUE-001", "title": "...", "severity": "...", "category": "..." }],
  "categoryScores": { "category": N }
}
```

## Phase 3: Transition

After the report:

> "N개 이슈를 발견했습니다. 수정하시겠습니까?
> A) Subagent-driven — 이슈별 병렬 수정 (`superpowers:subagent-driven-development`)
> B) Inline — 순차 수정 (`superpowers:executing-plans`)
> C) 아니오 — 리포트만 남기고 종료"

If A: invoke `superpowers:subagent-driven-development` with the report as input.
If B: invoke `superpowers:executing-plans` with the report as input.
If C: end.

## Completion Status

- **DONE** — All steps completed. Evidence provided for each claim.
- **BLOCKED** — Cannot proceed. State what is blocking.
- **NEEDS_CONTEXT** — Missing information required to continue.
```

- [ ] **Step 2: Verify line count and frontmatter**

Run: `wc -l plugins/me/skills/qa/SKILL.md && head -10 plugins/me/skills/qa/SKILL.md`
Expected: ~80 lines, frontmatter has `name: qa` and no browser tool in allowed-tools

- [ ] **Step 3: Verify no references to removed content**

Run: `grep -n 'bootstrap\|mcp__plugin\|WTF\|Fix Loop\|Phase 4\|regression\|--quick\|--exhaustive\|Tier' plugins/me/skills/qa/SKILL.md`
Expected: No matches

- [ ] **Step 4: Commit**

```bash
git add plugins/me/skills/qa/SKILL.md
git commit -m "feat(qa): rewrite as lean explore+report skill (~80 lines)"
```

---

### Task 5: Final verification

Verify all files are consistent and the skill is complete.

**Files:**
- Read: all files in `plugins/me/skills/qa/`

- [ ] **Step 1: Verify file structure**

Run: `find plugins/me/skills/qa/ -type f | sort`
Expected:
```
plugins/me/skills/qa/SKILL.md
plugins/me/skills/qa/references/exploration-guide.md
plugins/me/skills/qa/references/issue-taxonomy.md
plugins/me/skills/qa/templates/qa-report-template.md
```

- [ ] **Step 2: Verify SKILL.md references are valid**

Run: `grep 'qa/references\|qa/templates' plugins/me/skills/qa/SKILL.md`
Expected: references to `qa/references/exploration-guide.md`, `qa/references/issue-taxonomy.md`, `qa/templates/qa-report-template.md` — all exist

- [ ] **Step 3: Verify total token budget**

Run: `wc -l plugins/me/skills/qa/SKILL.md plugins/me/skills/qa/references/*.md plugins/me/skills/qa/templates/*.md`
Expected: SKILL.md ~80 lines, references ~120 lines, template ~45 lines

- [ ] **Step 4: Verify no orphan references**

Run: `grep -rn 'mcp__plugin_superpowers\|bootstrap\|Phase 3: Fix\|Phase 4: Final\|--quick\|--exhaustive' plugins/me/skills/qa/`
Expected: No matches in any file
