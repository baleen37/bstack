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
