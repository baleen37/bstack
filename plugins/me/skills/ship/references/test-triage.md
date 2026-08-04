# Test Failure Ownership Triage

When tests fail during `/ship`'s verification gate, do NOT immediately stop. First determine ownership.

## Step T1: Classify each failure

For each failing test:

1. **Get files changed on this branch:**
   ```bash
   git diff <base>...HEAD --name-only
   ```

2. **Classify:**
   - **In-branch** if: the failing test file itself was modified on this branch, OR the test references code that was changed on this branch, OR the failure traces to a branch change.
   - **Likely pre-existing** if: neither the test file nor the code under test was modified on this branch, AND the failure is unrelated to any branch change.
   - **When ambiguous, default to in-branch.** Safer to stop the developer than to let a broken test ship.

This is heuristic — use judgment reading the diff and test output.

## Step T2: Handle in-branch failures

**STOP.** These are your failures. Show them and do not proceed. The developer must fix their own broken tests before shipping.

## Step T3: Handle pre-existing failures

Use `AskUserQuestion`:

> These test failures appear pre-existing (not caused by your branch changes):
>
> [list each failure with file:line and brief error]
>
> Options:
> A) Investigate and fix now (commit fix separately)
> B) Add as P0 TODO — fix after this branch lands
> C) Skip — known issue, ship anyway

## Step T4: Execute

**Fix now:** Investigate root cause, minimal fix, commit separately as `fix: pre-existing test failure in <file>`. Continue.

**P0 TODO:** Append to `TODOS.md` (create if missing) with title, error output, branch noticed on, priority P0. Continue.

**Skip:** Continue. Note in output: "Pre-existing test failure skipped: <test-name>".

After triage: if any in-branch failures remain unfixed, **STOP**. Otherwise continue.
