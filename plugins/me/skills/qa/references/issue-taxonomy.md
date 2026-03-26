# QA Issue Taxonomy

## Severity Levels

| Severity | Definition | Examples |
|----------|------------|----------|
| **critical** | Blocks a core workflow, causes data loss, or crashes | Checkout flow broken, CLI crashes on valid input, API returns 500 on create, data deleted without confirmation |
| **high** | Major feature broken or unusable, no workaround | Search returns wrong results, command silently produces wrong output, auth endpoint rejects valid tokens |
| **medium** | Feature works but with noticeable problems, workaround exists | Slow response (>5s), validation missing but operation still works, error message unhelpful |
| **low** | Minor polish issue | Typo in help text, inconsistent formatting, unnecessary verbose output |

## Categories

Categories are universal. Not all apply to every project type — use the ones relevant to what you're testing.

### 1. Correctness
Output or behavior does not match specification or intent.
- Web: wrong page content, broken links, incorrect redirects
- CLI: wrong output for given input, incorrect exit codes
- API: wrong response body, incorrect status codes, spec violations
- Library: wrong return values, incorrect side effects

### 2. Error Handling
Failures are not handled gracefully or communicated clearly.
- Unclear error messages ("Something went wrong" with no detail)
- Unhandled exceptions (crashes, stack traces leaked to users)
- Missing validation (invalid input accepted silently)
- No confirmation before destructive actions

### 3. Edge Cases
Boundary conditions and unusual inputs cause unexpected behavior.
- Empty/null/missing inputs
- Extremely large inputs or payloads
- Special characters, unicode, encoding issues
- Concurrent/repeated operations (race conditions, double-submit, idempotency)
- State transitions (refresh, back/forward, reconnect)

### 4. Usability
The interface (UI, CLI, API) is confusing or inconsistent.
- Web: confusing navigation, dead ends, missing loading indicators
- CLI: unhelpful `--help`, inconsistent flags, debug noise on stdout
- API: inconsistent response formats, unclear field names, missing pagination
- Library: confusing API surface, undocumented behavior

### 5. Performance
Unacceptable latency or resource usage.
- Slow operations (>3s for user-facing, >30s for background)
- Excessive resource consumption (memory, network requests, file handles)
- Missing timeouts or backpressure

### 6. Security
Vulnerabilities or unsafe defaults.
- Credentials/tokens in logs or error output
- Missing auth checks, privilege escalation
- Injection vulnerabilities (SQL, command, XSS)
- Insecure defaults (permissive CORS, weak crypto)

### 7. Documentation
Public-facing docs are wrong or missing.
- README examples that don't work
- Outdated or incorrect help text
- Typos, placeholder text, truncated content
- Missing or unhelpful empty states

## Exploration Checklists

### Web Applications

For each page visited:

1. **Visual scan** — Take screenshot and read it. Look for layout issues, broken images, alignment.
2. **Interactive elements** — Click every button, link, and control. Does each do what it says?
3. **Forms** — Fill and submit. Test empty submission, invalid data, edge cases (long text, special characters).
4. **Navigation** — Check all paths in/out. Breadcrumbs, back button, deep links, mobile menu.
5. **States** — Check empty state, loading state, error state, full/overflow state.
6. **Console** — Run console error check after interactions. Any new JS errors or failed requests?
7. **Responsiveness** — If relevant, check mobile and tablet viewports.
8. **Auth boundaries** — What happens when logged out? Different user roles?

### CLI Tools

For each command/subcommand:

1. **Help text** — Does `--help` exist? Is it accurate and complete?
2. **Happy path** — Run with typical inputs. Correct output?
3. **Invalid inputs** — Wrong types, missing required args, unknown flags. Clear error messages?
4. **Edge cases** — Empty input, huge input, special characters, piped input, no TTY.
5. **Exit codes** — 0 on success, non-zero on failure? Consistent?
6. **stderr vs stdout** — Errors go to stderr? Output is parseable (no debug noise on stdout)?
7. **Combinations** — Do flags interact correctly? Conflicting flags handled?
8. **Idempotency** — Run the same command twice. Same result?

### API Servers

For each endpoint:

1. **Happy path** — Valid request, correct response code and body.
2. **Validation** — Missing fields, wrong types, boundary values. Proper 4xx responses?
3. **Auth** — Request without token, expired token, wrong role. Proper 401/403?
4. **Error responses** — Consistent format? Useful error messages? No stack traces leaked?
5. **Idempotency** — POST twice, PUT twice. Expected behavior?
6. **Content negotiation** — Correct Content-Type headers? Accepts declared formats?
7. **Edge cases** — Large payloads, empty bodies, unicode, special characters.
8. **Spec compliance** — If OpenAPI/Swagger exists, does the endpoint match?

### Libraries

For each public API surface:

1. **Test suite** — Run all tests. Note failures, slow tests, flaky tests.
2. **Coverage gaps** — Are there exported functions with no tests?
3. **Error messages** — When misused, are errors clear and actionable?
4. **Type safety** — Do types match runtime behavior? Any `any` leaks?
5. **Edge cases** — Boundary values, null/undefined, empty collections, concurrent usage.
6. **Documentation** — Do README examples actually work? Are they up to date?
7. **Backwards compatibility** — If there's a public API contract, is it honored?
