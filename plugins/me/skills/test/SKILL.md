---
name: test
description: Design, run, and improve tests for a change using project conventions and subagent verification.
disable-model-invocation: true
---

<!-- Adapted from https://github.com/addyosmani/agent-skills/tree/main -->

# /test: prove behavior with tests

Use `/test` when the user explicitly asks to test, verify, reproduce, harden, or add coverage for behavior.
This is an explicit workflow skill: it should run only when the user invokes it.

`/test` favors:

- Proving behavior with the smallest meaningful test
- Reproducing bugs before fixing them when feasible
- Testing observable outcomes over implementation details
- Focused checks before broad suites
- Evidence over confidence

## Test discovery

Before adding tests:

1. Inspect nearby tests for naming, fixtures, setup, and assertion style.
2. Identify the focused test command for the relevant area.
3. Prefer existing test utilities over new helpers.
4. Avoid introducing new test frameworks.

## Workflow

1. State the behavior under test.
2. Find the closest existing test pattern.
3. Add or update a focused test.
4. For bugs, confirm the test fails before the fix when feasible.
5. Implement or adjust only what is needed for the test to pass.
6. Run the focused test again.
7. Run the smallest relevant broader suite.
8. Summarize exact commands and results.

Use `debugging-and-error-recovery` for unexpected failures, `browse` for browser runtime behavior, and `qa` or `verify` for final evidence when appropriate.

## Subagent use

Use the `test-engineer` subagent for non-trivial testing work.

Ask `test-engineer` to inspect:

- Missing happy-path, edge-case, and error-path coverage
- Overly coupled assertions
- Flaky setup or timing assumptions
- Whether tests prove the requested behavior
- Whether broader verification is needed

For security-sensitive behavior, also use `security-auditor`. For large behavior changes, use `code-reviewer` after tests pass.

## Final response

Report:

- Behavior verified
- Tests added or changed
- Commands run
- Pass/fail results
- Remaining gaps
