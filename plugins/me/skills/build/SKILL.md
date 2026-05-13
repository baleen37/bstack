---
name: build
description: Incrementally build a feature or fix using small changes, tests, verification, and subagent review.
---

<!-- Adapted from https://github.com/addyosmani/agent-skills/tree/main -->

# /build: incremental implementation

Use `/build` when the user explicitly asks to implement a feature, fix a bug, or complete the next planned change.
This is an explicit workflow skill: it should run only when the user invokes it.

`/build` favors:

- Small, reversible changes
- Existing project conventions
- Test-first or test-near implementation
- No speculative abstractions
- Independent validation before claiming done

## Workflow

1. Clarify the target behavior and any assumptions that affect scope.
2. Inspect existing code, tests, and local patterns before editing.
3. Add or update the smallest meaningful test when the behavior can be tested.
4. Implement the minimum change needed to satisfy the target behavior.
5. Run the focused test or check first.
6. Run the smallest relevant broader verification.
7. Use subagents for independent validation when the change is non-trivial.
8. Report changed files, verification commands, results, and remaining risks.

For failures, use `debugging-and-error-recovery`. For runtime proof, use `verify` or `browse` when applicable.
For branch, commit, or release mechanics, use `git-workflow-and-versioning` rather than inventing a new flow.

## Subagent use

After the first working implementation and focused checks pass, dispatch subagents for independent review when the change is non-trivial.

Use:

- `test-engineer` to inspect coverage, edge cases, and failure modes.
- `code-reviewer` to review correctness, maintainability, and fit with local patterns.
- `security-auditor` when the change touches authentication, authorization, secrets, external input, network calls, file access, dependencies, or configuration.

Give each subagent a narrow prompt with:

- What changed
- Which files changed
- Which commands passed or failed
- Which risks to inspect

Do not ask subagents to rewrite the whole solution. Ask for findings and specific recommendations.

## Completion criteria

Before reporting done:

- Focused checks pass.
- Relevant broader checks pass, or failures are clearly explained.
- Subagent findings are addressed or explicitly deferred with rationale.
- The final response includes changed files, verification commands, results, and remaining risks.
