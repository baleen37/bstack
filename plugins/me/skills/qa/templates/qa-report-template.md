# QA Verification Report: {PROJECT_NAME}

## Verdict: {PASS | PARTIAL | FAIL}

## Scope

- **Target:** {what was verified}
- **Scope source:** {plan | branch | user override}
- **Branch:** {BRANCH}
- **Commit:** {COMMIT_SHA}
- **Duration:** {DURATION}

## Verification Summary

### Golden path
- {scenario} — PASS / PARTIAL / FAIL

### Key edge cases
- {scenario} — PASS / PARTIAL / FAIL

### Obvious regressions
- {scenario} — PASS / PARTIAL / FAIL

## Failed / Incomplete Scenarios

- {scenario} — {why it failed or remains incomplete}

## Evidence

- {path to log, screenshot, or HTTP response}
- {key command output or reproduction note}

## Issues

### ISSUE-001: {Short title}

| Field | Value |
|-------|-------|
| **Severity** | critical / high / medium / low |
| **Category** | correctness / error-handling / edge-case / usability / performance / security / documentation |
| **Location** | {where it was observed} |

**Description:** {What is wrong and why it matters to the verdict.}

## Next Actions

- {what to fix next}
- {what to re-verify next}
- {what remains before `/ship`}
