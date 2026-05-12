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

- Creating a failing test or repro before feature/bugfix work when feasible
- Proving behavior with the smallest meaningful test
- Testing observable user/system outcomes over implementation details
- Running the focused test command before the smallest relevant broader suite
- Verifying UI, browser, and runtime changes in the real runtime
- Evidence over confidence

## Test discovery

Before adding tests:

1. Inspect nearby tests for naming, fixtures, setup, and assertion style.
2. Identify the focused test command for the relevant area.
3. Prefer existing test utilities over new helpers.
4. Avoid introducing new test frameworks.

## Workflow

1. State the observable behavior under test from the user/system point of view.
2. Find the closest existing test pattern.
3. For features or bug fixes, add a failing focused test or repro first when feasible.
4. Confirm the focused test fails for the expected reason before changing implementation.
5. Implement or adjust only what is needed for the test to pass.
6. Run the focused test command again.
7. Run the smallest relevant broader suite after the focused check passes.
8. For UI, browser, or runtime changes, verify the real runtime with `browse`, `e2e`, or related verification.
9. Summarize exact commands, results, and remaining gaps.

Use `debugging-and-error-recovery` for unexpected failures, `browse` for browser runtime behavior, `e2e` for end-to-end
coverage, and `qa` or `verify` for final evidence when appropriate.

## Subagent use

Use the `test-engineer` subagent for non-trivial testing work.

Ask `test-engineer` to inspect:

- Missing happy-path, edge-case, and error-path coverage
- Whether a failing test or repro came before implementation when feasible
- Whether assertions prove observable behavior rather than implementation details
- Flaky setup or timing assumptions
- Whether focused and broader commands are appropriately scoped
- Whether runtime verification is needed

For security-sensitive behavior, also use `security-auditor`. For large behavior changes, use `code-reviewer` after
tests pass.

## Final response

Report:

- Behavior verified
- Tests added or changed
- Commands run, including focused command first and broader suite if run
- Pass/fail results for each command
- Runtime verification used, such as `browse`, `qa`, `verify`, or `e2e` when applicable
- Remaining gaps or unverified areas
