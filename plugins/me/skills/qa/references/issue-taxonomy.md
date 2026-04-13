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
