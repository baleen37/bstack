---
name: review
description: >-
  Review code changes for correctness, readability, architecture, security, performance, and test coverage using
  subagents.
disable-model-invocation: true
---

<!-- Adapted from https://github.com/addyosmani/agent-skills/tree/main -->

# /review: multi-axis code review

Use `/review` when the user explicitly asks to review a change, PR, branch, diff, or implementation.
This is an explicit workflow skill: it should run only when the user invokes it.

Review in this priority order. Correctness, security, and test coverage findings take precedence over style-only
concerns:

1. Correctness
2. Security and data safety
3. Test coverage
4. Maintainability and readability
5. Architecture fit
6. Performance

## Severity

- **Blocking:** A correctness bug, security risk, data loss risk, missing required test coverage, broken contract,
  regression, or deploy/runtime failure that should be fixed before merge.
- **Non-blocking:** A suggestion, style issue, readability improvement, minor refactor, or optional follow-up that does
  not make the change unsafe or incorrect.
- Treat unnecessary abstractions, speculative changes, and avoidable complexity as quality findings. Mark them blocking
  only when they materially obscure correctness, increase risk, or make the change hard to verify.

## Workflow

1. Inspect the diff and changed files.
2. Understand the intended behavior before judging the code.
3. Check correctness issues and missing edge cases.
4. Check tests for meaningful coverage.
5. Check security-sensitive paths. If the diff touches secrets, authentication, authorization, injection surfaces,
   dependencies, or configuration, use `security-auditor`.
6. Check maintainability and fit with local conventions, including needless abstraction, speculative change, and
   excessive complexity.
7. Separate blocking issues from non-blocking suggestions.
8. Provide concise findings with `file:line` evidence, impact, and an actionable recommendation.

## Subagent use

For non-trivial reviews, dispatch relevant subagents in parallel. Include `security-auditor` when the diff touches
secrets, authentication, authorization, injection surfaces, dependencies, or configuration:

- `code-reviewer`: correctness, maintainability, architecture, readability, unnecessary abstraction, speculative change,
  excessive complexity, and local convention fit.
- `security-auditor`: authentication, authorization, secrets, injection, unsafe file or network access, dependency and
  configuration risks.
- `test-engineer`: test coverage, missing cases, flaky tests, and verification gaps.

Each subagent should receive:

- The user's review goal
- The relevant diff or changed file list
- Any test commands already run
- A request for findings only, not broad rewrites or implementation changes
- A request to cite `file:line` evidence and provide actionable recommendations

After subagents respond:

1. Deduplicate overlapping findings.
2. Prioritize blocking issues first, especially correctness, security, and required test coverage gaps.
3. Include only actionable recommendations with `file:line` evidence.
4. Clearly mark non-blocking suggestions.

## Final report format

```markdown
### Verdict
PASS | PASS WITH COMMENTS | NEEDS CHANGES

### Blocking Issues
- [file:line] Issue, why it matters, and suggested fix.

### Non-blocking Suggestions
- [file:line] Suggestion and why it may improve the code.

### Verification
- Commands reviewed or run
- Results
- Gaps
```
