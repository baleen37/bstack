# Exploration Guide

Reference for QA exploration by project type. Suggestions, not mandatory — adapt to the project.

## Web Applications

1. **Visual scan** — layout issues, broken images, alignment
2. **Interactive elements** — click every button, link, control
3. **Forms** — empty submission, invalid data, edge cases (long text, special chars)
4. **Navigation** — all paths in/out, breadcrumbs, back button, deep links
5. **States** — empty, loading, error, overflow
6. **Console** — JS errors, failed network requests after interactions
7. **Responsiveness** — mobile/tablet viewports if relevant
8. **Auth boundaries** — logged out behavior, different roles

**Framework hints:** Next.js (hydration errors, `_next/data` 404s), Rails (N+1, CSRF), SPA (stale state, back/forward).

**Browser testing:** Use `/browse` skill for browser automation.

## CLI Tools

1. **Help text** — `--help` exists? Accurate?
2. **Happy path** — typical inputs, correct output
3. **Invalid inputs** — wrong types, missing args, unknown flags
4. **Edge cases** — empty, huge, special chars, piped input, no TTY
5. **Exit codes** — 0 success, non-zero fail, consistent
6. **stderr vs stdout** — errors to stderr, output parseable
7. **Flag combinations** — interact correctly? Conflicting flags handled?
8. **Idempotency** — same command twice, same result

## API Servers

1. **Happy path** — valid request, correct status and body
2. **Validation** — missing fields, wrong types, boundaries → proper 4xx
3. **Auth** — no token, expired, wrong role → 401/403
4. **Error responses** — consistent format, no stack traces leaked
5. **Idempotency** — POST/PUT twice, expected behavior
6. **Content negotiation** — correct Content-Type headers
7. **Edge cases** — large payloads, empty bodies, unicode
8. **Spec compliance** — matches OpenAPI/Swagger if exists

## Libraries

1. **Test suite** — run all, note failures/slow/flaky
2. **Coverage gaps** — untested exported functions
3. **Error messages** — clear and actionable on misuse
4. **Type safety** — types match runtime behavior
5. **Edge cases** — boundaries, null, empty collections
6. **Docs** — README examples actually work

## Other Projects

1. **Entry points** — identify primary interfaces
2. **Existing tests** — run whatever exists
3. **Main flows** — exercise end-to-end
4. **Error handling** — what happens when things go wrong
5. **Configuration** — defaults sensible, required configs documented
