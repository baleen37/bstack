# QA Skill Generalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generalize the `/qa` skill from web-only to support any project type (web, CLI, API, library) with a simplified 5-phase universal flow.

**Architecture:** Single SKILL.md rewrite — 11 web-specific phases become 5 universal phases. Type-specific guidance lives inline. Supporting files (issue taxonomy, report template) are generalized to remove web-only assumptions.

**Tech Stack:** Markdown skill files, no code dependencies.

**Spec:** `docs/superpowers/specs/2026-03-26-qa-generalization-design.md`

---

### Task 1: Rewrite SKILL.md — 5-Phase Universal Flow

**Files:**
- Modify: `plugins/me/skills/qa/SKILL.md`

The entire SKILL.md is rewritten. The new structure:

1. Frontmatter — updated description, same allowed-tools
2. Intro — universal QA engineer framing
3. Browser Tool — kept but scoped to "when testing web projects"
4. Setup section — params, tiers, clean tree, test framework bootstrap, output dirs
5. Phase 1: Setup
6. Phase 2: Explore — universal flow + type-specific strategies (web, CLI, API, library)
7. Phase 3: Fix Loop — triage + fix cycle (largely preserved from current 8a-8f)
8. Phase 4: Final QA
9. Phase 5: Report
10. Health Score Rubric — universal scoring mechanic, no fixed categories
11. Rules — generalized from current web-specific rules
12. Output Structure
13. Completion Status

- [ ] **Step 1: Write the new SKILL.md**

Replace the entire contents of `plugins/me/skills/qa/SKILL.md` with:

````markdown
---
name: qa
description: Systematically QA test a project and fix bugs found. Runs QA testing,
  then iteratively fixes bugs in source code, committing each fix atomically and
  re-verifying. Use when asked to "qa", "QA", "test this", "find bugs",
  "test and fix", or "fix what's broken".
  Proactively suggest when the user says a feature is ready for testing
  or asks "does this work?". Three tiers: Quick (critical/high only),
  Standard (+ medium), Exhaustive (+ cosmetic). Produces before/after health scores,
  fix evidence, and a ship-readiness summary. For report-only mode, use /qa-only.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - mcp__plugin_superpowers-chrome_chrome__use_browser
---

# /qa: Explore → Fix → Verify → Report

You are a QA engineer AND a bug-fix engineer. Test projects like a real user — run commands, click through UIs, call APIs, exercise edge cases. When you find bugs, fix them in source code with atomic commits, then re-verify. Produce a structured report with before/after evidence.

## Browser Tool (Web Projects)

When testing web projects, use `mcp__plugin_superpowers-chrome_chrome__use_browser` for all browser interactions:

| Operation | Action | Example |
|-----------|--------|---------|
| Navigate to URL | `navigate` | `{action: "navigate", payload: "https://example.com"}` |
| Take screenshot | `screenshot` | `{action: "screenshot", payload: "/path/to/file.png"}` |
| Read page content | `extract` | `{action: "extract", payload: "markdown"}` |
| Click element | `click` | `{action: "click", selector: "button.submit"}` |
| Type into input | `type` | `{action: "type", selector: "#email", payload: "user@example.com"}` |
| Run JS | `eval` | `{action: "eval", payload: "JSON.stringify(window.__errors || [])"}` |
| Wait for element | `await_element` | `{action: "await_element", selector: ".loaded", timeout: 10000}` |

**After every navigate or screenshot:** use the Read tool on the screenshot file to show the user the visual result inline.

**Console error collection (inject once after navigate, collect after interactions):**
```javascript
// Inject:
window.__qaErrors = []; window.addEventListener('error', e => window.__qaErrors.push({type:'error',msg:e.message,url:e.filename,line:e.lineno})); window.addEventListener('unhandledrejection', e => window.__qaErrors.push({type:'promise',msg:String(e.reason)}));

// Collect:
JSON.stringify(window.__qaErrors)
```

---

## Parameters

Parse from the user's request:

| Parameter | Default | Override example |
|-----------|---------|-----------------:|
| Target | (infer from project) | URL, command name, API base URL |
| Tier | Standard | `--quick`, `--exhaustive` |
| Mode | full | `--regression .qa/reports/baseline.json` |
| Output dir | `.qa/reports/` | `Output to /tmp/qa` |
| Scope | Full project (or diff-scoped) | `Focus on the auth module` |

**Tiers determine which issues get fixed:**
- **Quick:** Fix critical + high severity only
- **Standard:** + medium severity (default)
- **Exhaustive:** + low/cosmetic severity

---

## Test Framework Bootstrap

**Detect existing test framework and project runtime:**

```bash
[ -f Gemfile ] && echo "RUNTIME:ruby"
[ -f package.json ] && echo "RUNTIME:node"
[ -f requirements.txt ] || [ -f pyproject.toml ] && echo "RUNTIME:python"
[ -f go.mod ] && echo "RUNTIME:go"
[ -f Cargo.toml ] && echo "RUNTIME:rust"
ls jest.config.* vitest.config.* playwright.config.* .rspec pytest.ini pyproject.toml phpunit.xml 2>/dev/null
ls -d test/ tests/ spec/ __tests__/ cypress/ e2e/ 2>/dev/null
[ -f .qa/no-test-bootstrap ] && echo "BOOTSTRAP_DECLINED"
```

**If test framework detected:** Print "Test framework detected: {name}. Skipping bootstrap." Read 2-3 existing test files to learn conventions. **Skip the rest of bootstrap.**

**If BOOTSTRAP_DECLINED:** Print "Test bootstrap previously declined — skipping." **Skip the rest of bootstrap.**

**If runtime detected but no test framework — bootstrap:**

| Runtime | Primary | Alternative |
|---------|---------|-------------|
| Ruby/Rails | minitest + fixtures + capybara | rspec + factory_bot |
| Node.js | vitest + @testing-library | jest + @testing-library |
| Next.js | vitest + @testing-library/react + playwright | jest + cypress |
| Python | pytest + pytest-cov | unittest |
| Go | stdlib testing + testify | stdlib only |
| Rust | cargo test (built-in) | — |

Ask the user which framework to use, install it, create a minimal config, and run a smoke test to verify.

If the user declines: write `.qa/no-test-bootstrap` and continue.

After bootstrap: write `TESTING.md` with run command, conventions, and test expectations. Append a `## Testing` section to `CLAUDE.md` if it doesn't already have one. Commit: `"chore: bootstrap test framework ({name})"`.

---

## Modes

### Diff-aware (automatic when on a feature branch)

1. **Analyze the branch diff:**
   ```bash
   git diff main...HEAD --name-only
   git log main..HEAD --oneline
   ```

2. **Identify affected areas** from the changed files — routes, CLI commands, API endpoints, library functions, etc.

3. **Test each affected area** using the appropriate strategy for the project type.

4. **Cross-reference with commit messages** to verify the code does what the commits claim.

### Full (default)
Systematic exploration of the entire project surface. Document 5-10 well-evidenced issues. Produce health score.

### Quick (`--quick`)
Smoke test. Hit the main entry points. Check: does it run? Obvious errors? Core flow works? Produce health score.

### Regression (`--regression <baseline>`)
Run full mode, then load `baseline.json` from a previous run. Diff: which issues are fixed? Which are new? Score delta?

---

## Phase 1: Setup

1. Parse parameters from user's request
2. Check for clean working tree:
   ```bash
   git status --porcelain
   ```
   If dirty, **STOP** and ask: "Your working tree has uncommitted changes. /qa needs a clean tree so each bug fix gets its own atomic commit. Options: A) Commit my changes, B) Stash my changes, C) Abort"
3. Create output directories:
   ```bash
   mkdir -p .qa/reports/evidence
   ```
4. Copy report template from `qa/templates/qa-report-template.md` to output dir
5. Detect test framework (see bootstrap section above)
6. Record start time: `_QA_START=$(date +%s)`

---

## Phase 2: Explore

Systematically test the project. The approach depends on what you're testing.

### Web Applications

1. **Orient:** Navigate to the target URL, screenshot the landing page, extract navigation links, collect console errors.
2. **Explore pages:** Visit pages systematically. At each page: screenshot, check console, test interactive elements, forms, navigation, states (empty/loading/error/overflow), responsiveness.
3. **Auth flows:** If auth is needed, handle login. Never include credentials in reports — write `[REDACTED]`.
4. **Framework hints:**
   - Next.js: check for hydration errors, `_next/data` 404s, test client-side navigation
   - Rails: check N+1 warnings, CSRF tokens, Turbo/Stimulus integration
   - SPA: use `extract` for navigation (link eval may miss client-side routes), check stale state, back/forward history

### CLI Tools

1. **Orient:** Read README, help text (`--help`), and man pages. Identify all commands and flags.
2. **Run commands:** Execute with typical inputs, edge cases (empty input, huge input, invalid flags, missing args), and combinations.
3. **Check outputs:** Verify stdout, stderr, and exit codes are correct and consistent.
4. **Run test suite:** Execute existing tests, note any failures.
5. **Cross-reference:** Compare test results with manual execution findings.

### API Servers

1. **Orient:** Find API spec (OpenAPI/Swagger) if available. Read route definitions. Identify all endpoints.
2. **Hit endpoints:** Send real HTTP requests with valid inputs, invalid inputs, missing auth, edge cases.
3. **Check responses:** Verify status codes, response bodies, headers, error formats.
4. **Auth flows:** Test token/session lifecycle — login, refresh, expiry, invalid tokens.
5. **Spec compliance:** If a spec exists, verify every endpoint matches it.
6. **Run test suite:** Execute existing tests, note any failures.

### Libraries

1. **Orient:** Read public API surface — exports, type definitions, README examples.
2. **Run test suite:** Execute all tests, note failures and coverage gaps.
3. **API usability:** Check for confusing error messages, missing validation, undocumented behavior.
4. **Edge cases:** Exercise boundary conditions the test suite may have missed.

### Mixed Projects

Test each aspect using the appropriate strategy above.

### Documentation Rules

- Document each issue **immediately when found** — don't batch.
- Every issue needs evidence (screenshot, command output, HTTP response, test output).
- Verify reproducibility — retry the issue once before documenting.

---

## Phase 3: Fix Loop

### Triage

Sort discovered issues by severity. Decide which to fix based on tier:
- **Quick:** critical + high only. Mark rest as "deferred."
- **Standard:** critical + high + medium. Mark low as "deferred."
- **Exhaustive:** Fix all.

Mark issues that cannot be fixed from source (third-party bugs, infrastructure) as "deferred" regardless of tier.

### Per-Issue Fix Cycle

For each fixable issue, in severity order:

**3a. Locate source**
```bash
# Grep for error messages, component names, route definitions, command handlers
# Glob for file patterns matching the affected area
```

**3b. Fix**
- Read the source code, understand the context
- Make the **minimal fix** — smallest change that resolves the issue
- Do NOT refactor surrounding code, add features, or "improve" unrelated things

**3c. Commit**
```bash
git add <only-changed-files>
git commit -m "fix(qa): ISSUE-NNN — short description"
```
One commit per fix. Never bundle multiple fixes.

**3d. Re-test**
Verify the fix using the same method that found the issue (browser, CLI run, HTTP request, test suite).

**3e. Classify**
- **verified**: re-test confirms the fix works, no new errors
- **best-effort**: fix applied but couldn't fully verify
- **reverted**: regression detected → `git revert HEAD` → mark as "deferred"

**3f. Regression Test**

Skip if: classification is not "verified", OR no test framework detected AND user declined bootstrap.

1. Study 2-3 existing test files closest to the fix. Match conventions.
2. Write a regression test that:
   - Sets up the precondition that triggered the bug
   - Performs the action that exposed the bug
   - Asserts the correct behavior
   - Includes attribution comment:
     ```
     // Regression: ISSUE-NNN — {what broke}
     // Found by /qa on {YYYY-MM-DD}
     // Report: .qa/reports/qa-report-{date}.md
     ```
3. Run only the new test file. Passes → commit. Fails → delete, defer.

### Self-Regulation

Every 5 fixes (or after any revert), compute WTF-likelihood:

```
Start at 0%
Each revert:                +15%
Each fix touching >3 files: +5%
After fix 15:               +1% per additional fix
All remaining Low severity: +10%
Touching unrelated files:   +20%
```

**If WTF > 20%:** STOP. Show the user progress so far. Ask whether to continue.

**Hard cap: 50 fixes.**

---

## Phase 4: Final QA

After all fixes are applied:

1. Re-test all affected areas using the same methods from Phase 2
2. Compute final health score
3. **If final score is WORSE than baseline:** WARN prominently — something regressed

---

## Phase 5: Report

1. Write report to `.qa/reports/qa-report-{YYYY-MM-DD}.md` using the template
2. Save `baseline.json`:
   ```json
   {
     "date": "YYYY-MM-DD",
     "target": "<what was tested>",
     "healthScore": N,
     "issues": [{ "id": "ISSUE-001", "title": "...", "severity": "...", "category": "..." }],
     "categoryScores": { "category": N }
   }
   ```
3. If the repo has `TODOS.md`:
   - New deferred bugs → add as TODOs with severity, category, and repro steps
   - Fixed bugs that were in TODOS.md → annotate with "Fixed by /qa on {branch}, {date}"

---

## Health Score

Choose categories appropriate to the project. There is no fixed set — pick what makes sense.

**Examples:**
- Web: Console, Links, Visual, Functional, UX, Performance, Accessibility
- CLI: Output Correctness, Error Handling, Edge Cases, Documentation, Performance
- API: Response Correctness, Validation, Auth, Error Handling, Spec Compliance, Performance
- Library: Test Coverage, API Usability, Error Messages, Edge Cases, Documentation

**Scoring mechanic (universal):**
Each category starts at 100. Deduct per finding:
- Critical: -25
- High: -15
- Medium: -8
- Low: -3
Minimum 0 per category.

Assign weights that sum to 100%. Weight core functionality higher than polish.

`score = Σ (category_score × weight)`

---

## Rules

1. **Evidence is everything.** Every issue needs proof — screenshot, command output, HTTP response, or test output. No exceptions.
2. **Verify before documenting.** Retry the issue once to confirm reproducibility.
3. **Never include credentials.** Write `[REDACTED]` for passwords in repro steps.
4. **Write incrementally.** Append each issue to the report as you find it.
5. **Test as a user.** Use realistic inputs. Walk through complete workflows end-to-end.
6. **Depth over breadth.** 5-10 well-documented issues with evidence > 20 vague descriptions.
7. **Never delete output files.** Evidence and reports accumulate — that's intentional.
8. **Show evidence to the user.** After capturing evidence (screenshots, outputs), display it inline.
9. **Clean working tree required.** If dirty, offer commit/stash/abort before proceeding.
10. **One commit per fix.** Never bundle multiple fixes into one commit.
11. **Only modify tests when generating regression tests in Phase 3f.** Never modify existing tests — only create new test files.
12. **Revert on regression.** If a fix makes things worse, `git revert HEAD` immediately.
13. **Self-regulate.** Follow the WTF-likelihood heuristic. When in doubt, stop and ask.

---

## Output Structure

```
.qa/reports/
├── qa-report-{YYYY-MM-DD}.md    # Structured report
├── evidence/
│   ├── initial.png
│   ├── issue-001-step-1.png
│   ├── issue-001-before.png
│   ├── issue-001-after.png
│   ├── issue-002-output.txt
│   └── ...
└── baseline.json
```

---

## Completion Status

Report status using one of:
- **DONE** — All steps completed. Evidence provided for each claim.
- **DONE_WITH_CONCERNS** — Completed, but with issues the user should know about.
- **BLOCKED** — Cannot proceed. State what is blocking and what was tried.
- **NEEDS_CONTEXT** — Missing information required to continue.

If you have attempted a task 3 times without success, STOP and escalate.
````

- [ ] **Step 2: Verify the new SKILL.md**

Read the file back and confirm:
- Frontmatter is valid YAML
- 5 phases are present (Setup, Explore, Fix Loop, Final QA, Report)
- Browser Tool section is scoped to web projects
- Type-specific exploration guidance exists for web, CLI, API, library
- Health Score has no fixed categories
- Rules are generic (no web-only assumptions)
- All preserved features are present: tiers, diff-aware mode, regression mode, test bootstrap, fix loop, WTF-likelihood, 50-fix cap

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/qa/SKILL.md
git commit -m "feat(qa): generalize skill from web-only to universal 5-phase flow"
```

---

### Task 2: Extend issue-taxonomy.md with Type-Aware Exploration Checklists

**Files:**
- Modify: `plugins/me/skills/qa/references/issue-taxonomy.md`

The severity levels and existing categories stay. The Per-Page Exploration Checklist becomes type-aware with checklists for web, CLI, API, and library projects.

- [ ] **Step 1: Update issue-taxonomy.md**

Replace the `## Per-Page Exploration Checklist` section (lines 74-86) with the following. Keep everything above line 74 unchanged:

```markdown
## Exploration Checklists

### Web Applications

For each page visited:

1. **Visual scan** — Take screenshot and read it. Look for layout issues, broken images, alignment.
2. **Interactive elements** — Click every button, link, and control. Does each do what it says?
3. **Forms** — Fill and submit. Test empty submission, invalid data, edge cases (long text, special characters).
4. **Navigation** — Check all paths in/out. Breadcrumbs, back button, deep links, mobile menu.
5. **States** — Check empty state, loading state, error state, full/overflow state.
6. **Console** — Run console error check after interactions. Any new JS errors or failed requests?
7. **Responsiveness** — If relevant, check mobile and tablet viewports.
8. **Auth boundaries** — What happens when logged out? Different user roles?

### CLI Tools

For each command/subcommand:

1. **Help text** — Does `--help` exist? Is it accurate and complete?
2. **Happy path** — Run with typical inputs. Correct output?
3. **Invalid inputs** — Wrong types, missing required args, unknown flags. Clear error messages?
4. **Edge cases** — Empty input, huge input, special characters, piped input, no TTY.
5. **Exit codes** — 0 on success, non-zero on failure? Consistent?
6. **stderr vs stdout** — Errors go to stderr? Output is parseable (no debug noise on stdout)?
7. **Combinations** — Do flags interact correctly? Conflicting flags handled?
8. **Idempotency** — Run the same command twice. Same result?

### API Servers

For each endpoint:

1. **Happy path** — Valid request, correct response code and body.
2. **Validation** — Missing fields, wrong types, boundary values. Proper 4xx responses?
3. **Auth** — Request without token, expired token, wrong role. Proper 401/403?
4. **Error responses** — Consistent format? Useful error messages? No stack traces leaked?
5. **Idempotency** — POST twice, PUT twice. Expected behavior?
6. **Content negotiation** — Correct Content-Type headers? Accepts declared formats?
7. **Edge cases** — Large payloads, empty bodies, unicode, special characters.
8. **Spec compliance** — If OpenAPI/Swagger exists, does the endpoint match?

### Libraries

For each public API surface:

1. **Test suite** — Run all tests. Note failures, slow tests, flaky tests.
2. **Coverage gaps** — Are there exported functions with no tests?
3. **Error messages** — When misused, are errors clear and actionable?
4. **Type safety** — Do types match runtime behavior? Any `any` leaks?
5. **Edge cases** — Boundary values, null/undefined, empty collections, concurrent usage.
6. **Documentation** — Do README examples actually work? Are they up to date?
7. **Backwards compatibility** — If there's a public API contract, is it honored?
```

- [ ] **Step 2: Verify the update**

Read the file back and confirm:
- Severity Levels and Categories sections are unchanged
- Four exploration checklists exist: Web, CLI, API, Library
- Web checklist matches the previous Per-Page content

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/qa/references/issue-taxonomy.md
git commit -m "feat(qa): add CLI, API, and library exploration checklists to taxonomy"
```

---

### Task 3: Generalize qa-report-template.md

**Files:**
- Modify: `plugins/me/skills/qa/templates/qa-report-template.md`

Remove web-only assumptions. All fields become optional or generic. The template should work for any project type.

- [ ] **Step 1: Write the new report template**

Replace the entire contents of `plugins/me/skills/qa/templates/qa-report-template.md` with:

```markdown
# QA Report: {PROJECT_NAME}

| Field | Value |
|-------|-------|
| **Date** | {DATE} |
| **Target** | {what was tested — URL, CLI command, API base, package name} |
| **Branch** | {BRANCH} |
| **Commit** | {COMMIT_SHA} ({COMMIT_DATE}) |
| **PR** | {PR_NUMBER} ({PR_URL}) or "—" |
| **Tier** | Quick / Standard / Exhaustive |
| **Scope** | {SCOPE or "Full project"} |
| **Duration** | {DURATION} |
| **Areas tested** | {COUNT} |
| **Evidence files** | {COUNT} |

## Health Score: {SCORE}/100

| Category | Weight | Score |
|----------|--------|-------|
| {category} | {weight}% | {0-100} |
| ... | ... | ... |

## Top 3 Things to Fix

1. **{ISSUE-NNN}: {title}** — {one-line description}
2. **{ISSUE-NNN}: {title}** — {one-line description}
3. **{ISSUE-NNN}: {title}** — {one-line description}

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
| **Category** | {project-appropriate category} |
| **Location** | {URL, command, endpoint, function — whatever is relevant} |

**Description:** {What is wrong, expected vs actual.}

**Repro Steps:**

1. {Action}
   ![Evidence](evidence/issue-001-step-1.png) or `{command output}`
2. {Action}
3. **Observe:** {what goes wrong}

---

## Fixes Applied

| Issue | Fix Status | Commit | Files Changed |
|-------|-----------|--------|---------------|
| ISSUE-NNN | verified / best-effort / reverted / deferred | {SHA} | {files} |

### Before/After Evidence

#### ISSUE-NNN: {title}
**Before:** ![Before](evidence/issue-NNN-before.png) or `{output before}`
**After:** ![After](evidence/issue-NNN-after.png) or `{output after}`

---

## Regression Tests

| Issue | Test File | Status | Description |
|-------|-----------|--------|-------------|
| ISSUE-NNN | path/to/test | committed / deferred / skipped | description |

---

## Ship Readiness

| Metric | Value |
|--------|-------|
| Health score | {before} → {after} ({delta}) |
| Issues found | N |
| Fixes applied | N (verified: X, best-effort: Y, reverted: Z) |
| Deferred | N |

**Summary:** "QA found N issues, fixed M, health score X → Y."

---

## Regression (if applicable)

| Metric | Baseline | Current | Delta |
|--------|----------|---------|-------|
| Health score | {N} | {N} | {+/-N} |
| Issues | {N} | {N} | {+/-N} |

**Fixed since baseline:** {list}
**New since baseline:** {list}
```

- [ ] **Step 2: Verify the update**

Read the file back and confirm:
- No web-specific field names (URL → Target, Pages visited → Areas tested, Screenshots → Evidence files)
- Health Score categories are dynamic (table with `{category}` placeholder, not fixed list)
- Issue Location field is generic, not "URL"
- Evidence references use `evidence/` directory, not `screenshots/`
- Evidence can be screenshots OR command output (both shown in template)
- No Console Health section (absorbed into dynamic health score categories)

- [ ] **Step 3: Commit**

```bash
git add plugins/me/skills/qa/templates/qa-report-template.md
git commit -m "feat(qa): generalize report template for any project type"
```

---

### Task 4: Verify Consistency Across All Three Files

- [ ] **Step 1: Cross-reference check**

Read all three files and verify:
- SKILL.md references `qa/references/issue-taxonomy.md` — path still valid
- SKILL.md references `qa/templates/qa-report-template.md` — path still valid
- SKILL.md output structure says `evidence/` — template uses `evidence/` (not `screenshots/`)
- SKILL.md health score description matches template's dynamic category table
- SKILL.md phases match the flow described in this plan
- Issue taxonomy checklists cover the same project types as SKILL.md Phase 2

- [ ] **Step 2: Fix any inconsistencies found**

If the cross-reference check reveals mismatches, fix them and amend the relevant commit.

- [ ] **Step 3: Final commit (if needed)**

Only if Step 2 produced changes:
```bash
git add -A
git commit -m "fix(qa): resolve cross-file inconsistencies in generalized skill"
```
