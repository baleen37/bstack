---
name: review
description: Review code changes for correctness, readability, architecture, security, performance, and test coverage using subagents.
disable-model-invocation: true
---

<!-- Adapted from https://github.com/addyosmani/agent-skills/tree/main -->

# /review: multi-axis code review

Use `/review` when the user explicitly asks to review a change, PR, branch, diff, or implementation.
This is an explicit workflow skill: it should run only when the user invokes it.

Review in this priority order:

1. Correctness
2. Security and data safety
3. Test coverage
4. Maintainability and readability
5. Architecture fit
6. Performance

## Workflow

1. Inspect the diff and changed files.
2. Understand the intended behavior before judging the code.
3. Check correctness issues and missing edge cases.
4. Check tests for meaningful coverage.
5. Check security-sensitive paths.
6. Check maintainability and fit with local conventions.
7. Separate blocking issues from suggestions.
8. Provide concise findings with file paths and reasoning.

## Subagent use

For non-trivial reviews, dispatch subagents in parallel:

- `code-reviewer`: correctness, maintainability, architecture, readability, and local convention fit.
- `security-auditor`: authentication, authorization, secrets, injection, unsafe file or network access, dependency and configuration risks.
- `test-engineer`: test coverage, missing cases, flaky tests, and verification gaps.

Each subagent should receive:

- The user's review goal
- The relevant diff or changed file list
- Any test commands already run
- A request for findings only, not broad rewrites

After subagents respond:

1. Deduplicate overlapping findings.
2. Prioritize blocking issues first.
3. Include only actionable recommendations.
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
