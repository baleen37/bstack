---
name: eval-harness
description: This skill should be used when the user asks to "set up eval-driven development", "define eval criteria", "create evals", "measure pass@k", "benchmark agent reliability", "add regression evals", "grade agent output", or mentions EDD, capability evals, regression evals, or pass@k metrics for AI agent tasks.
---

# Eval Harness

## Overview

Eval-Driven Development (EDD) treats evals as the unit tests of AI development.

**Core principle:** Define expected behavior BEFORE implementation, run evals continuously, track regressions with each change.

Evals answer the question: "Does this agent reliably do what we expect?"

## When to Use

```text
Need to evaluate AI agent behavior?
    │
    ├─ Defining pass/fail criteria for Claude Code tasks? → YES
    ├─ Measuring agent reliability with pass@k? → YES
    ├─ Creating regression suites for prompt/agent changes? → YES
    ├─ Benchmarking across model versions? → YES
    └─ Simple deterministic unit test? → NO (use standard testing)
```

**Use for:**

- Defining expected AI behavior before implementation
- Tracking capability regressions across prompt or model changes
- Measuring reliability with pass@k and pass^k metrics
- Grading open-ended outputs with code, model, or human graders

**Don't use for:**

- Standard unit/integration tests (use existing test frameworks)
- Deterministic code with predictable outputs
- One-off manual testing

## Eval Types

### Capability Evals

Test if Claude can do something it couldn't before:

```markdown
[CAPABILITY EVAL: feature-name]
Task: Description of what Claude should accomplish
Success Criteria:
  - [ ] Criterion 1
  - [ ] Criterion 2
  - [ ] Criterion 3
Expected Output: Description of expected result
```

### Regression Evals

Ensure changes don't break existing functionality:

```markdown
[REGRESSION EVAL: feature-name]
Baseline: SHA or checkpoint name
Tests:
  - existing-test-1: PASS/FAIL
  - existing-test-2: PASS/FAIL
  - existing-test-3: PASS/FAIL
Result: X/Y passed (previously Y/Y)
```

## Grader Types

### 1. Code-Based Grader (Preferred)

Deterministic checks — always prefer when possible:

```bash
# Check if file contains expected pattern
grep -q "export function handleAuth" src/auth.ts && echo "PASS" || echo "FAIL"

# Check if tests pass
npm test -- --testPathPattern="auth" && echo "PASS" || echo "FAIL"

# Check if build succeeds
npm run build && echo "PASS" || echo "FAIL"
```

### 2. Model-Based Grader

Use Claude to evaluate open-ended outputs:

```markdown
[MODEL GRADER PROMPT]
Evaluate the following code change:
1. Does it solve the stated problem?
2. Is it well-structured?
3. Are edge cases handled?
4. Is error handling appropriate?

Score: 1-5 (1=poor, 5=excellent)
Reasoning: [explanation]
```

### 3. Human Grader

Flag for manual review when automated grading is insufficient:

```markdown
[HUMAN REVIEW REQUIRED]
Change: Description of what changed
Reason: Why human review is needed
Risk Level: LOW/MEDIUM/HIGH
```

## Metrics

### pass@k

"At least one success in k attempts"

| Metric | Meaning | Target |
| :--- | :--- | :--- |
| pass@1 | First attempt success rate | Baseline |
| pass@3 | Success within 3 attempts | > 90% |

### pass^k

"All k trials succeed" — higher bar for critical paths:

| Metric | Meaning | Use Case |
| :--- | :--- | :--- |
| pass^3 | 3 consecutive successes | Critical paths, regression evals |

## Workflow

### 1. Define (Before Coding)

```markdown
## EVAL DEFINITION: feature-xyz

### Capability Evals
1. Can create new user account
2. Can validate email format
3. Can hash password securely

### Regression Evals
1. Existing login still works
2. Session management unchanged
3. Logout flow intact

### Success Metrics
- pass@3 > 90% for capability evals
- pass^3 = 100% for regression evals
```

### 2. Implement

Write code to pass the defined evals.

### 3. Evaluate

Run each eval, record PASS/FAIL, run regression suite.

### 4. Report

```markdown
EVAL REPORT: feature-xyz
========================

Capability Evals:
  create-user:     PASS (pass@1)
  validate-email:  PASS (pass@2)
  hash-password:   PASS (pass@1)
  Overall:         3/3 passed

Regression Evals:
  login-flow:      PASS
  session-mgmt:    PASS
  logout-flow:     PASS
  Overall:         3/3 passed

Metrics:
  pass@1: 67% (2/3)
  pass@3: 100% (3/3)

Status: READY FOR REVIEW
```

## Eval Storage

```
.claude/
  evals/
    feature-xyz.md      # Eval definition
    feature-xyz.log     # Eval run history
    baseline.json       # Regression baselines
```

## Rationalizations Table

| Excuse | Reality |
| :--- | :--- |
| "Evals slow us down" | Wrong implementation causes slowdowns. Evals prevent rework. |
| "This change is too small for evals" | Small changes cause big regressions. Define criteria anyway. |
| "I'll add evals after implementation" | Post-hoc evals test what was built, not what should have been built. |
| "Model-based grading is good enough" | Code graders are deterministic. Prefer them when possible. |
| "pass@1 failed but pass@3 passed" | Investigate WHY the first attempt failed. Flaky evals hide real issues. |
| "Regression suite is green, ship it" | Green regression + missing capability evals = incomplete picture. |
| "Manual testing covers this" | Manual testing is not reproducible. Automate it. |
| "Security is covered by tests" | Never fully automate security checks. Human review is mandatory. |

## Red Flags

These thoughts mean STOP:

- Defining success criteria AFTER writing code
- No regression evals for an existing feature change
- Using only model-based graders when code-based graders are possible
- Skipping eval definition because "the change is obvious"
- Reporting pass@3 without investigating pass@1 failures
- No eval storage — evals must be versioned with code
- Trusting a green regression suite without capability evals
- Skipping human review for security-related changes

**Any of these = STOP and define evals first.**

## Common Mistakes

| Mistake | Fix |
| :--- | :--- |
| Evals defined after implementation | Define evals BEFORE coding — forces clear success criteria |
| No regression baseline | Capture baseline BEFORE making changes |
| Code grader not used when possible | Always prefer deterministic code graders over model graders |
| Evals not versioned | Store evals in `.claude/evals/` alongside code |
| Ignoring pass@1 failures | Investigate every first-attempt failure — flakiness hides real bugs |
| Security evaluated only by model | Human review is mandatory for security changes |
| Eval suite too slow to run | Keep evals fast — slow evals don't get run |
| Missing negative evals | Test what should NOT happen, not just what should |

## Example: Adding Authentication

```markdown
## EVAL: add-authentication

### Phase 1: Define
Capability Evals:
- [ ] User can register with email/password
- [ ] User can login with valid credentials
- [ ] Invalid credentials rejected with proper error
- [ ] Sessions persist across page reloads
- [ ] Logout clears session

Regression Evals:
- [ ] Public routes still accessible
- [ ] API responses unchanged
- [ ] Database schema compatible

### Phase 2: Implement
[Write code]

### Phase 3: Evaluate
Run evals, record results.

### Phase 4: Report
EVAL REPORT: add-authentication
==============================
Capability: 5/5 passed (pass@3: 100%)
Regression: 3/3 passed (pass^3: 100%)
Status: SHIP IT
```
