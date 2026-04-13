# Exploration Guide

Reference for QA exploration by project type. These are suggestions, not mandatory checklists — adapt to the project.

## Web Applications

For each page: visual scan, click all interactive elements, test forms (empty/invalid/edge cases), check navigation paths, verify states (empty/loading/error/overflow), check console for JS errors, test responsiveness if relevant, verify auth boundaries.

**Framework hints:** Next.js (hydration errors, `_next/data` 404s), Rails (N+1, CSRF), SPA (stale state, back/forward).

**Browser testing:** Use `/browse` skill for browser automation.

## CLI Tools

For each command: verify `--help` accuracy, run happy path, test invalid inputs (wrong types, missing args, unknown flags), edge cases (empty/huge/special chars/piped/no TTY), check exit codes (0 success, non-zero fail), verify stderr vs stdout separation, test flag combinations, check idempotency.

## API Servers

For each endpoint: happy path, validation (missing fields, wrong types, boundaries → proper 4xx), auth (no token, expired, wrong role → 401/403), error response consistency, idempotency (POST/PUT twice), content negotiation, edge cases (large payloads, empty bodies, unicode), spec compliance if OpenAPI exists.

## Libraries

Test suite (failures, slow, flaky), coverage gaps (untested exports), error message quality, type safety, edge cases (boundaries, null, empty collections), README examples accuracy.

## Other Projects

Identify entry points, run existing tests, exercise main flows end-to-end, check error handling, review configuration defaults and docs.
