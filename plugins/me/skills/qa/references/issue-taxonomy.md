# QA Issue Taxonomy

## Severity Levels

| Severity | Definition | Examples |
|----------|------------|----------|
| **critical** | Blocks a core workflow, causes data loss, or crashes the app | Form submit causes error page, checkout flow broken, data deleted without confirmation |
| **high** | Major feature broken or unusable, no workaround | Search returns wrong results, file upload silently fails, auth redirect loop |
| **medium** | Feature works but with noticeable problems, workaround exists | Slow page load (>5s), form validation missing but submit still works, layout broken on mobile only |
| **low** | Minor cosmetic or polish issue | Typo in footer, 1px alignment issue, hover state inconsistent |

## Categories

### 1. Visual/UI
- Layout breaks (overlapping elements, clipped text, horizontal scrollbar)
- Broken or missing images
- Incorrect z-index (elements appearing behind others)
- Font/color inconsistencies
- Animation glitches (jank, incomplete transitions)
- Alignment issues (off-grid, uneven spacing)
- Dark mode / theme issues

### 2. Functional
- Broken links (404, wrong destination)
- Dead buttons (click does nothing)
- Form validation (missing, wrong, bypassed)
- Incorrect redirects
- State not persisting (data lost on refresh, back button)
- Race conditions (double-submit, stale data)
- Search returning wrong or no results

### 3. UX
- Confusing navigation (no breadcrumbs, dead ends)
- Missing loading indicators (user doesn't know something is happening)
- Slow interactions (>500ms with no feedback)
- Unclear error messages ("Something went wrong" with no detail)
- No confirmation before destructive actions
- Inconsistent interaction patterns across pages
- Dead ends (no way back, no next action)

### 4. Content
- Typos and grammar errors
- Outdated or incorrect text
- Placeholder / lorem ipsum text left in
- Truncated text (cut off without ellipsis or "more")
- Wrong labels on buttons or form fields
- Missing or unhelpful empty states

### 5. Performance
- Slow page loads (>3 seconds)
- Janky scrolling (dropped frames)
- Layout shifts (content jumping after load)
- Excessive network requests (>50 on a single page)
- Large unoptimized images
- Blocking JavaScript (page unresponsive during load)

### 6. Console/Errors
- JavaScript exceptions (uncaught errors)
- Failed network requests (4xx, 5xx)
- Deprecation warnings (upcoming breakage)
- CORS errors
- Mixed content warnings (HTTP resources on HTTPS)
- CSP violations

### 7. Accessibility
- Missing alt text on images
- Unlabeled form inputs
- Keyboard navigation broken (can't tab to elements)
- Focus traps (can't escape a modal or dropdown)
- Missing or incorrect ARIA attributes
- Insufficient color contrast
- Content not reachable by screen reader

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
