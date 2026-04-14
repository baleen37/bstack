---
name: e2e
description: Use when changes span multiple components, services, or layers and unit/integration tests alone cannot confirm the full flow works correctly
---

# End-to-End Verification

## Overview

E2e verification confirms that a complete user-visible flow works across all touched components. Unit and integration tests verify parts; e2e verification confirms they connect correctly.

**Core principle:** If your changes cross a service boundary, data layer, or user-facing interface, verify the full path — not just the individual pieces.

## When to Use

하나라도 해당하면 e2e 필요: 2+ 컴포넌트 통신 변경 → API 계약 변경 → 데이터 플로우 변경. 모두 아니면 skip.

**vs `me:qa`:** e2e는 특정 변경사항의 서비스 연결 검증. qa는 기능/품질 관점에서 버그 탐색 + 리포트 (QA 엔지니어 역할). 배포 전 서비스 연결 확인이면 e2e, 광범위 버그 탐색이면 qa.

**Needs e2e:**
- Changes span 2+ services/components that communicate
- API contracts changed (request/response shape, endpoints)
- Data flows through multiple layers (API → service → DB → notification)
- External integrations changed (payment providers, email services, third-party APIs)

**Skip e2e:**
- Pure refactoring with no behavior change (confirmed by existing tests)
- Isolated utility functions with comprehensive unit tests
- Documentation-only changes
- Single-component changes fully covered by integration tests

## The Pattern: Trace, Criteria, Execute, Report

### Step 1: Trace the Flow

Map the complete path your change affects, from entry point to final side effect.

```
Entry point → [Component A] → [Component B] → ... → Final side effect
```

Example:
```
POST /api/order → cart service → inventory check → payment API → order DB → confirmation email
```

**What to trace:**
- Data: What goes in? What comes out at each step?
- Side effects: DB writes, emails, external API calls, file changes
- Error paths: What happens when step N fails?

### Step 2: Define Pass/Fail Criteria

For EACH step in the flow, state the concrete expected outcome.

| Step | Action | Pass Criteria |
|------|--------|---------------|
| 1 | POST /api/order with valid cart | 200, order ID returned |
| 2 | Check inventory | Stock decremented by ordered quantity |
| 3 | Payment API call | Charge created, transaction ID stored |
| 4 | DB state | Order record with status=confirmed, correct amounts |
| 5 | Email | Confirmation sent with correct order details |

**Bad criteria:** "Check that it works" / "Verify the response" / "Make sure email sends"
**Good criteria:** "Response status 200 with JSON containing `order_id` string" / "Email contains order #X and total $Y"

### Step 3: Execute In Dependency Order

Verify bottom-up: infrastructure → data → API → flow → side effects.

1. **Infrastructure:** Can services reach each other? Are APIs up? Are credentials valid?
2. **Data layer:** Does the schema support the new flow? Do migrations work?
3. **API contracts:** Do requests/responses match between services?
4. **Full flow:** Run the happy path end-to-end
5. **Error paths:** Trigger each failure mode and verify graceful handling
6. **Side effects:** Confirm all external effects (emails, webhooks, file outputs)

**Stop at the first failure.** Fix it before proceeding — downstream steps depend on upstream ones.

### Step 4: Report Results

```
## E2E Verification: [flow name]

### Scope
[What was changed and why e2e is needed]

### Results
| Step | Status | Evidence |
|------|--------|----------|
| Infrastructure | PASS | Services responding on expected ports |
| DB migration | PASS | New column exists, default values correct |
| API contract | FAIL | Payment service returns `txn_id`, order service expects `transaction_id` |

### Blocking Issue
[Description of first failure, root cause if known]
```

## Adapting to What You Can Verify

Not every step is directly verifiable from your environment. Be explicit about what you CAN and CANNOT check.

| Can verify | How |
|-----------|-----|
| API responses | curl, httpie, test scripts |
| DB state | SQL queries, ORM console |
| Log output | grep logs, structured log queries |
| File output | Read generated files |
| Local email | Mailhog, Mailtrap, or similar |

| Cannot verify (delegate) | Who |
|--------------------------|-----|
| Production email delivery | Human or monitoring |
| Browser UI rendering | Human or Playwright/Cypress |
| Mobile app behavior | Human or mobile test framework |
| Third-party webhook reception | Third-party dashboard or logs |

**State what you verified and what you couldn't.** Never claim "e2e verified" when steps were skipped.

## Common Mistakes

**Checking only the happy path.** The happy path usually works. It's the error paths and edge cases that break across service boundaries.

**Vague pass criteria.** "It works" is not a criterion. State the specific expected output, status code, DB state, or side effect.

**Testing in wrong order.** If the DB migration is broken, API tests will fail with confusing errors. Go bottom-up.

**Skipping the report.** If you don't report what was and wasn't verified, your partner can't judge coverage.

**Over-verifying.** A typo fix doesn't need e2e. Use the decision flowchart. Unnecessary e2e wastes time and teaches you to skip it when it matters.
