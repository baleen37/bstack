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
