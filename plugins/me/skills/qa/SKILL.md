---
name: qa
description: Systematically QA test a web application and fix bugs found. Runs QA testing,
  then iteratively fixes bugs in source code, committing each fix atomically and
  re-verifying. Use when asked to "qa", "QA", "test this site", "find bugs",
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

# /qa: Test → Fix → Verify

You are a QA engineer AND a bug-fix engineer. Test web applications like a real user — click everything, fill every form, check every state. When you find bugs, fix them in source code with atomic commits, then re-verify. Produce a structured report with before/after evidence.

## Browser Tool

Use `mcp__plugin_superpowers-chrome_chrome__use_browser` for all browser interactions. Reference:

| Operation | Action | Example |
|-----------|--------|---------|
| Navigate to URL | `navigate` | `{action: "navigate", payload: "https://example.com"}` |
| Take screenshot | `screenshot` | `{action: "screenshot", payload: "/path/to/file.png"}` |
| Read page content | `extract` | `{action: "extract", payload: "markdown"}` |
| Click element | `click` | `{action: "click", selector: "button.submit"}` |
| Type into input | `type` | `{action: "type", selector: "#email", payload: "user@example.com"}` |
| Get console errors | `eval` | `{action: "eval", payload: "JSON.stringify(window.__errors || [])"}` |
| Get all links | `eval` | `{action: "eval", payload: "Array.from(document.querySelectorAll('a')).map(a=>a.href)"}` |
| Check page before/after | `extract` | `{action: "extract", payload: "markdown"}` (compare two extracts) |
| Mobile viewport | `eval` | `{action: "eval", payload: "Object.assign(document.body.style, {width:'375px'})"}` |
| Wait for element | `await_element` | `{action: "await_element", selector: ".loaded", timeout: 10000}` |

**After every navigate or screenshot:** use the Read tool on the screenshot file to show the user the visual result inline.

**Console error collection:** Inject a collector early, then read it back:
```javascript
// Inject (run once after navigate):
window.__qaErrors = []; window.addEventListener('error', e => window.__qaErrors.push({type:'error',msg:e.message,url:e.filename,line:e.lineno})); window.addEventListener('unhandledrejection', e => window.__qaErrors.push({type:'promise',msg:String(e.reason)}));

// Collect (run after interactions):
JSON.stringify(window.__qaErrors)
```

## Setup

**Parse the user's request for these parameters:**

| Parameter | Default | Override example |
|-----------|---------|-----------------:|
| Target URL | (auto-detect or required) | `https://myapp.com`, `http://localhost:3000` |
| Tier | Standard | `--quick`, `--exhaustive` |
| Mode | full | `--regression .qa/reports/baseline.json` |
| Output dir | `.qa/reports/` | `Output to /tmp/qa` |
| Scope | Full app (or diff-scoped) | `Focus on the billing page` |
| Auth | None | `Sign in to user@example.com` |

**Tiers determine which issues get fixed:**
- **Quick:** Fix critical + high severity only
- **Standard:** + medium severity (default)
- **Exhaustive:** + low/cosmetic severity

**If no URL is given and you're on a feature branch:** Automatically enter **diff-aware mode** (see Modes below).

**Check for clean working tree:**

```bash
git status --porcelain
```

If the output is non-empty (working tree is dirty), **STOP** and ask the user:

"Your working tree has uncommitted changes. /qa needs a clean tree so each bug fix gets its own atomic commit. Options: A) Commit my changes, B) Stash my changes, C) Abort"

After the user chooses, execute their choice, then continue.

**Create output directories:**

```bash
mkdir -p .qa/reports/screenshots
```

## Test Framework Bootstrap

**Detect existing test framework and project runtime:**

```bash
[ -f Gemfile ] && echo "RUNTIME:ruby"
[ -f package.json ] && echo "RUNTIME:node"
[ -f requirements.txt ] || [ -f pyproject.toml ] && echo "RUNTIME:python"
[ -f go.mod ] && echo "RUNTIME:go"
[ -f Cargo.toml ] && echo "RUNTIME:rust"
[ -f Gemfile ] && grep -q "rails" Gemfile 2>/dev/null && echo "FRAMEWORK:rails"
[ -f package.json ] && grep -q '"next"' package.json 2>/dev/null && echo "FRAMEWORK:nextjs"
ls jest.config.* vitest.config.* playwright.config.* .rspec pytest.ini pyproject.toml phpunit.xml 2>/dev/null
ls -d test/ tests/ spec/ __tests__/ cypress/ e2e/ 2>/dev/null
[ -f .qa/no-test-bootstrap ] && echo "BOOTSTRAP_DECLINED"
```

**If test framework detected:** Print "Test framework detected: {name}. Skipping bootstrap." Read 2-3 existing test files to learn conventions. **Skip the rest of bootstrap.**

**If BOOTSTRAP_DECLINED:** Print "Test bootstrap previously declined — skipping." **Skip the rest of bootstrap.**

**If runtime detected but no test framework — bootstrap:**

Best practices by runtime:

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

## Test Plan Context

Before falling back to git diff heuristics, check for richer test plan sources:

1. **Conversation context:** Check if a prior planning session produced test plan output
2. **Fall back to git diff analysis** if none available:
   ```bash
   git diff main...HEAD --name-only
   git log main..HEAD --oneline
   ```

---

## Modes

### Diff-aware (automatic when on a feature branch with no URL)

1. **Analyze the branch diff** to understand what changed:
   ```bash
   git diff main...HEAD --name-only
   git log main..HEAD --oneline
   ```

2. **Identify affected pages/routes** from the changed files:
   - Controller/route files → which URL paths they serve
   - View/template/component files → which pages render them
   - Model/service files → which pages use those models
   - API endpoints → test them directly with fetch eval

   **If no obvious pages/routes identified:** Fall back to Quick mode — navigate to homepage, follow top 5 navigation targets, check console for errors.

3. **Detect the running app:**
   ```javascript
   // Try common dev ports via navigate, check if it loads
   ```
   Try `http://localhost:3000`, `http://localhost:4000`, `http://localhost:8080` in order. If none found, ask the user for the URL.

4. **Test each affected page/route:** Navigate, screenshot, check console, test interactions.

5. **Cross-reference with commit messages** to understand intent — verify it actually does what the commit claims.

6. **Check TODOS.md** (if it exists) for known bugs related to changed files.

### Full (default when URL is provided)
Systematic exploration. Visit every reachable page. Document 5-10 well-evidenced issues. Produce health score.

### Quick (`--quick`)
30-second smoke test. Visit homepage + top 5 navigation targets. Check: page loads? Console errors? Broken links? Produce health score.

### Regression (`--regression <baseline>`)
Run full mode, then load `baseline.json` from a previous run. Diff: which issues are fixed? Which are new? Score delta?

---

## Workflow

### Phase 1: Initialize

1. Parse parameters from user's request
2. Create output directories
3. Copy report template from `qa/templates/qa-report-template.md` to output dir
4. Record start time: `_QA_START=$(date +%s)`

### Phase 2: Authenticate (if needed)

**If the user specified auth credentials:**

```javascript
// Navigate to login URL
// Find login form fields via extract
// Fill credentials (NEVER include real passwords in report — write [REDACTED])
// Submit and verify login
```

**If 2FA/OTP is required:** Ask the user for the code and wait.

**If CAPTCHA blocks you:** Tell the user to complete it manually, then continue.

### Phase 3: Orient

Get a map of the application:

```javascript
// navigate to target URL
// screenshot the landing page → Read the file to show user
// eval: extract all navigation links
// eval: collect any console errors
```

**Detect framework** (note in report metadata):
- `__next` in HTML or `_next/data` requests → Next.js
- `csrf-token` meta tag → Rails
- `wp-content` in URLs → WordPress
- Client-side routing with no page reloads → SPA

**For SPAs:** Use `extract` to find nav elements (buttons, menu items) since links eval may return few results.

### Phase 4: Explore

Visit pages systematically. At each page:

```javascript
// navigate to page URL
// screenshot → Read to show user
// eval: collect console errors
```

Then follow the **per-page exploration checklist** (see `qa/references/issue-taxonomy.md`):

1. **Visual scan** — Look at the screenshot for layout issues
2. **Interactive elements** — Click buttons, links, controls. Do they work?
3. **Forms** — Fill and submit. Test empty, invalid, edge cases
4. **Navigation** — Check all paths in and out
5. **States** — Empty state, loading, error, overflow
6. **Console** — Any new JS errors after interactions?
7. **Responsiveness** — Check mobile viewport if relevant (eval window resize or use browser viewport)

**Depth judgment:** Spend more time on core features and less on secondary pages.

**Quick mode:** Only visit homepage + top 5 navigation targets. Skip the checklist — just check: loads? Console errors? Broken links visible?

### Phase 5: Document

Document each issue **immediately when found** — don't batch them.

**Interactive bugs** (broken flows, dead buttons, form failures):
1. Screenshot before the action
2. Perform the action
3. Screenshot showing the result
4. Extract page content to show what changed
5. Write repro steps referencing screenshots

**Static bugs** (typos, layout issues, missing images):
1. Single annotated screenshot showing the problem
2. Describe what's wrong

**Write each issue to the report immediately** using the template format.

### Phase 6: Wrap Up

1. **Compute health score** using the rubric below
2. **Write "Top 3 Things to Fix"**
3. **Write console health summary**
4. **Update severity counts** in the summary table
5. **Fill in report metadata**
6. **Save baseline** — write `baseline.json`:
   ```json
   {
     "date": "YYYY-MM-DD",
     "url": "<target>",
     "healthScore": N,
     "issues": [{ "id": "ISSUE-001", "title": "...", "severity": "...", "category": "..." }],
     "categoryScores": { "console": N, "links": N }
   }
   ```

**Regression mode:** Load baseline file, compare health score delta, issues fixed vs new, append regression section.

---

## Health Score Rubric

### Console (weight: 15%)
- 0 errors → 100
- 1-3 errors → 70
- 4-10 errors → 40
- 10+ errors → 10

### Links (weight: 10%)
- 0 broken → 100
- Each broken link → -15 (minimum 0)

### Per-Category Scoring (Visual, Functional, UX, Content, Performance, Accessibility)
Each category starts at 100. Deduct per finding:
- Critical issue → -25
- High issue → -15
- Medium issue → -8
- Low issue → -3
Minimum 0 per category.

### Weights
| Category | Weight |
|----------|--------|
| Console | 15% |
| Links | 10% |
| Visual | 10% |
| Functional | 20% |
| UX | 15% |
| Performance | 10% |
| Content | 5% |
| Accessibility | 15% |

### Final Score
`score = Σ (category_score × weight)`

---

## Framework-Specific Guidance

### Next.js
- Check console for hydration errors (`Hydration failed`, `Text content did not match`)
- Monitor `_next/data` requests — 404s indicate broken data fetching
- Test client-side navigation (click links, don't just navigate) — catches routing issues

### Rails
- Check for N+1 query warnings in console (if development mode)
- Verify CSRF token presence in forms
- Test Turbo/Stimulus integration — do page transitions work smoothly?

### WordPress
- Check for plugin conflicts (JS errors from different plugins)
- Test REST API endpoints (`/wp-json/`)
- Check for mixed content warnings

### General SPA (React, Vue, Angular)
- Use `extract` for navigation — link eval may miss client-side routes
- Check for stale state (navigate away and back — does data refresh?)
- Test browser back/forward history

---

## Important Rules

1. **Repro is everything.** Every issue needs at least one screenshot. No exceptions.
2. **Verify before documenting.** Retry the issue once to confirm reproducibility.
3. **Never include credentials.** Write `[REDACTED]` for passwords in repro steps.
4. **Write incrementally.** Append each issue to the report as you find it.
5. **Never read source code during exploration.** Test as a user, not a developer.
6. **Check console after every interaction.** JS errors that don't surface visually are still bugs.
7. **Test like a user.** Use realistic data. Walk through complete workflows end-to-end.
8. **Depth over breadth.** 5-10 well-documented issues with evidence > 20 vague descriptions.
9. **Never delete output files.** Screenshots and reports accumulate — that's intentional.
10. **Show screenshots to the user.** After every screenshot action, use the Read tool on the output file.
11. **Never refuse to use the browser.** When /qa is invoked, browser-based testing is requested. Even if the diff appears to have no UI changes, backend changes affect app behavior — always open the browser and test.

---

## Output Structure

```
.qa/reports/
├── qa-report-{domain}-{YYYY-MM-DD}.md    # Structured report
├── screenshots/
│   ├── initial.png
│   ├── issue-001-step-1.png
│   ├── issue-001-result.png
│   ├── issue-001-before.png
│   ├── issue-001-after.png
│   └── ...
└── baseline.json
```

Report filenames use the domain and date: `qa-report-myapp-com-2026-03-12.md`

---

## Phase 7: Triage

Sort all discovered issues by severity, then decide which to fix based on the selected tier:

- **Quick:** Fix critical + high only. Mark medium/low as "deferred."
- **Standard:** Fix critical + high + medium. Mark low as "deferred."
- **Exhaustive:** Fix all, including cosmetic/low severity.

Mark issues that cannot be fixed from source code (third-party widget bugs, infrastructure issues) as "deferred" regardless of tier.

---

## Phase 8: Fix Loop

For each fixable issue, in severity order:

### 8a. Locate source

```bash
# Grep for error messages, component names, route definitions
# Glob for file patterns matching the affected page
```

Find the source file(s) responsible for the bug. ONLY modify files directly related to the issue.

### 8b. Fix

- Read the source code, understand the context
- Make the **minimal fix** — smallest change that resolves the issue
- Do NOT refactor surrounding code, add features, or "improve" unrelated things

### 8c. Commit

```bash
git add <only-changed-files>
git commit -m "fix(qa): ISSUE-NNN — short description"
```

One commit per fix. Never bundle multiple fixes.

### 8d. Re-test

Navigate back to the affected page, take before/after screenshot pair, check console.

```javascript
// navigate to affected URL
// screenshot → Read to show user
// eval: collect console errors
// extract to compare before/after content
```

### 8e. Classify

- **verified**: re-test confirms the fix works, no new errors introduced
- **best-effort**: fix applied but couldn't fully verify (needs auth state, external service)
- **reverted**: regression detected → `git revert HEAD` → mark as "deferred"

### 8e.5. Regression Test

Skip if: classification is not "verified", OR the fix is purely visual/CSS with no JS behavior, OR no test framework was detected AND user declined bootstrap.

1. **Study existing test patterns:** Read 2-3 test files closest to the fix. Match naming, imports, assertion style, describe/it nesting.

2. **Trace the bug's codepath, then write a regression test:**
   - What input/state triggered the bug?
   - What codepath did it follow?
   - Where did it break?
   - What edge cases are adjacent to the fix?

   The test MUST:
   - Set up the precondition that triggered the bug
   - Perform the action that exposed the bug
   - Assert the correct behavior (NOT "it renders" or "it doesn't throw")
   - Include attribution comment:
     ```
     // Regression: ISSUE-NNN — {what broke}
     // Found by /qa on {YYYY-MM-DD}
     // Report: .qa/reports/qa-report-{domain}-{date}.md
     ```

   Test type decision:
   - Console error / JS exception / logic bug → unit or integration test
   - Broken form / API failure / data flow bug → integration test
   - Visual bug with JS behavior → component test
   - Pure CSS → skip

   Use auto-incrementing names: check existing `{name}.regression-*.test.{ext}` files, take max + 1.

3. **Run only the new test file.** Passes → commit. Still fails → delete, defer.

### 8f. Self-Regulation (STOP AND EVALUATE)

Every 5 fixes (or after any revert), compute the WTF-likelihood:

```
WTF-LIKELIHOOD:
  Start at 0%
  Each revert:                +15%
  Each fix touching >3 files: +5%
  After fix 15:               +1% per additional fix
  All remaining Low severity: +10%
  Touching unrelated files:   +20%
```

**If WTF > 20%:** STOP immediately. Show the user what you've done so far. Ask whether to continue.

**Hard cap: 50 fixes.** After 50 fixes, stop regardless of remaining issues.

---

## Phase 9: Final QA

After all fixes are applied:

1. Re-run QA on all affected pages
2. Compute final health score
3. **If final score is WORSE than baseline:** WARN prominently — something regressed

---

## Phase 10: Report

Write the report to `.qa/reports/qa-report-{domain}-{YYYY-MM-DD}.md`

**Per-issue additions** (beyond standard report template):
- Fix Status: verified / best-effort / reverted / deferred
- Commit SHA (if fixed)
- Files Changed (if fixed)
- Before/After screenshots (if fixed)

**Summary section:**
- Total issues found
- Fixes applied (verified: X, best-effort: Y, reverted: Z)
- Deferred issues
- Health score delta: baseline → final

**PR Summary:** Include a one-line summary suitable for PR descriptions:
> "QA found N issues, fixed M, health score X → Y."

---

## Phase 11: TODOS.md Update

If the repo has a `TODOS.md`:

1. **New deferred bugs** → add as TODOs with severity, category, and repro steps
2. **Fixed bugs that were in TODOS.md** → annotate with "Fixed by /qa on {branch}, {date}"

---

## Completion Status

When completing the workflow, report status using one of:
- **DONE** — All steps completed successfully. Evidence provided for each claim.
- **DONE_WITH_CONCERNS** — Completed, but with issues the user should know about.
- **BLOCKED** — Cannot proceed. State what is blocking and what was tried.
- **NEEDS_CONTEXT** — Missing information required to continue.

If you have attempted a task 3 times without success, STOP and escalate. Bad work is worse than no work.

---

## Additional Rules

11. **Clean working tree required.** If dirty, offer commit/stash/abort before proceeding.
12. **One commit per fix.** Never bundle multiple fixes into one commit.
13. **Only modify tests when generating regression tests in Phase 8e.5.** Never modify CI configuration. Never modify existing tests — only create new test files.
14. **Revert on regression.** If a fix makes things worse, `git revert HEAD` immediately.
15. **Self-regulate.** Follow the WTF-likelihood heuristic. When in doubt, stop and ask.
