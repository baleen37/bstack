---
name: verify
description: Prove the change works. Reproduces unexpected behavior with systematic debugging, then validates browser-runtime behavior with playwright-cli. Composes the `debugging-and-error-recovery` and `browse` skills.
---

# /verify: prove it works

`/verify` is a **composition skill** that runs the two "Verify — prove it works" practices end-to-end against the current change. It does not introduce new procedure of its own; it sequences existing skills so that an agent (or user) running `/verify` always covers both the *root-cause* axis and the *runtime* axis before claiming a change is done.

The two underlying skills:

| Skill | What it does | Use when |
| --- | --- | --- |
| [`debugging-and-error-recovery`](../debugging-and-error-recovery/SKILL.md) | Five-step triage: reproduce, localize, reduce, fix, guard. Stop-the-line rule, safe fallbacks. | Tests fail, builds break, or behavior is unexpected. |
| [`browse`](../browse/SKILL.md) | playwright-cli for live runtime data — DOM inspection, console logs, network traces, performance profiling. | Building or debugging anything that runs in a browser. |

## When to run `/verify`

- Before declaring a task done if the change touches runtime behavior (UI, API responses, build pipelines).
- Before merging a PR that claims "fixes bug X" — `/verify` forces you to reproduce X first, then prove it's gone.
- After a refactor in a browser-runtime path: regressions hide in console errors, layout shifts, and network-call ordering that static review will not catch.

Skip `/verify` only when the change is purely textual (docs, comments) or when verification has already been completed in this session and no code has changed since.

## Phase 1 — Root-cause pass (`debugging-and-error-recovery`)

Invoke the `debugging-and-error-recovery` skill and walk its five-step triage against the current change:

1. **Reproduce** — write a failing test or capture an exact repro command. No fix proceeds without a deterministic repro.
2. **Localize** — bisect by file, function, or commit until the minimum surface is identified.
3. **Reduce** — strip the repro to the smallest input that still triggers the failure.
4. **Fix** — apply the minimum change. No drive-by refactors.
5. **Guard** — add a regression test or assertion so the failure cannot return silently.

If the change is greenfield (no existing failure to reproduce), still run steps 1 and 5: write the test that proves the new behavior, and keep it as the regression guard.

**Stop-the-line rule.** If at any step a *different* defect surfaces (unexpected console error, unrelated test fail), stop and triage it before continuing — do not silence or work around it.

## Phase 2 — Runtime pass (`browse`)

If the change runs in a browser, invoke the `browse` skill and use playwright-cli to verify against live runtime data:

- **DOM** — confirm the rendered structure matches the expectation, not just the source JSX/HTML.
- **Console** — zero unhandled errors or warnings introduced by this change.
- **Network** — request count, payload shape, status codes, and ordering match the design.
- **Performance** — no new long tasks, layout thrash, or memory leaks on the critical path.
- **Visual** — screenshot or visual diff for any user-facing surface.

If the change is server-only or CLI-only, skip Phase 2 and document why in the verification report.

## Phase 3 — Verification report

Produce a single output the user (or downstream skill like `/ship`) can read:

```markdown
## Verification: PASS | PARTIAL | FAIL

### Root-cause pass (debugging-and-error-recovery)
- Repro: [command or test name + result before fix]
- Fix scope: [files/functions touched]
- Regression guard: [test name + result after fix]

### Runtime pass (browse)
- DOM: [observation]
- Console: [error/warning count]
- Network: [requests verified]
- Performance: [notable metrics]
- Visual: [screenshot path or N/A]

### Outstanding risks
- [Anything not verified, with reason]
```

## Rules

1. `/verify` runs Phase 1 always; Phase 2 only if the change has a browser runtime surface.
2. The verification report is mandatory — a `PASS` claim without the report is invalid.
3. `/verify` does not modify code on its own. If Phase 1 surfaces a fix, apply the fix in a separate step and re-run `/verify`.
4. If either phase returns `FAIL`, the overall verdict is `FAIL` regardless of the other phase.
