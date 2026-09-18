---
name: diagnosing-bugs
description: Use when something is broken, throwing, failing, flaky, or slow and the cause is not obvious — "diagnose this", "debug this", "why is this failing?", "this is intermittent", "this got slow". Builds a feedback loop that goes red on the bug before theorising, then fixes with a regression test. Not for bugs whose cause you already know, and not for writing new features.
---

# Diagnosing Bugs

A discipline for hard bugs: the one that resists a first glance, the
intermittent flake, the regression that crept in between two known-good
states. Skip phases only when you can say why.

**Announce at start:** "I'm using the diagnosing-bugs skill to track this down."

## Redact

This skill has you show commands, outputs, and captured artifacts. **Redact
every secret first** — write `<REDACTED>` in its place. Build loops against
environment variables so credentials stay in the environment rather than in
what you show. Captured artifacts carry auth headers: quote only the lines
that carry the signal.

If the redacted output is not enough to diagnose the bug, say so and ask.

## Phase 1: Build a feedback loop

**This is the skill.** Everything else is mechanical. If you have a **tight**
pass/fail signal for the bug — one that goes red on *this* bug — you will find
the cause; bisection, hypothesis-testing, and instrumentation all just consume
it. Without one, no amount of reading code will save you.

Spend disproportionate effort here. Be aggressive, be creative, refuse to give
up.

### Ways to construct one, in roughly this order

1. **Failing test** at whatever seam reaches the bug: unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a
   known-good snapshot.
4. **Headless browser script** that drives the UI and asserts on DOM,
   console, or network.
5. **Replay a captured trace.** Save a real request, payload, or event log to
   disk; replay it through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of the system (one
   service, mocked deps) that exercises the bug path in a single call.
7. **Property / fuzz loop.** For "sometimes wrong output", run 1000 random
   inputs and look for the failure mode.
8. **Bisection harness.** If the bug appeared between two known states,
   automate "boot at state X, check, repeat" so `git bisect run` can drive it.
9. **Differential loop.** Run the same input through two versions or configs
   and diff the outputs.
10. **Human in the loop.** Last resort, when a person must click. Hand them a
    numbered checklist with the exact thing to observe at each step, and have
    them paste back the output. Keep it structured so the result still feeds
    the loop.

### Tighten the loop

Treat the loop as a product. Once you have *a* loop, **tighten** it:

- Faster? Cache setup, skip unrelated init, narrow the test scope.
- Sharper signal? Assert the specific symptom, not "didn't crash".
- More deterministic? Pin time, seed RNG, isolate the filesystem, freeze
  network.

A 30-second flaky loop is barely better than none; a 2-second deterministic
one is a different tool entirely.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the
trigger 100×, parallelise, add stress, narrow timing windows, inject sleeps. A
50%-flake bug is debuggable; 1% is not. Keep raising the rate until it is.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what you tried, then ask for one of: access
to an environment that reproduces it, a redacted captured artifact (HAR, log
dump, core dump, screen recording with timestamps), or permission to add
temporary production instrumentation.

Do **not** proceed to hypothesise without a loop.

### Completion criterion

Phase 1 is done when you can name **one command** — a script path, a test
invocation, a curl — that you have **already run at least once** (show the
invocation and its output, redacted), and that is:

- **Red-capable**: drives the actual bug code path and asserts the user's
  exact symptom, so it goes red now and green once fixed. Not "runs without
  erroring" — it must be able to catch *this* bug.
- **Deterministic**: same verdict every run (flaky bugs: a pinned, high
  reproduction rate).
- **Fast**: seconds, not minutes.
- **Agent-runnable**: you can run it unattended.

If you catch yourself reading code to build a theory before this command
exists, **stop** — jumping to a hypothesis is the exact failure this skill
prevents. No red-capable command, no Phase 2.

## Phase 2: Reproduce and minimise

Run the loop. Watch it go red.

Confirm all three:

- The loop produces the failure the **user** described, not a different one
  nearby. Wrong bug means wrong fix.
- The failure repeats across runs (or, for flaky bugs, at a high enough rate).
- You captured the exact symptom — error text, wrong output, slow timing — so
  later phases can verify the fix addresses it.

### Minimise

Shrink to the **smallest scenario that still goes red**. Cut inputs, callers,
config, data, and steps **one at a time**, re-running after each cut. Keep
only what is load-bearing.

This is not tidiness: a minimal repro shrinks the hypothesis space in Phase 3
and becomes the regression test in Phase 5.

Done when removing any remaining element makes the loop go green.

## Phase 3: Hypothesise

Generate **3-5 ranked hypotheses before testing any of them**. Generating one
at a time anchors you on the first plausible idea.

Each must be **falsifiable** — state the prediction it makes:

> "If X is the cause, then changing Y will make the bug disappear / changing Z
> will make it worse."

If you cannot state the prediction, it is a vibe. Sharpen it or discard it.

**Show the ranked list before testing.** Your human partner often re-ranks it
instantly ("we just deployed a change to #3") or has already ruled one out.
Cheap checkpoint, large payoff. Don't block on it — proceed with your ranking
if they are away.

## Phase 4: Instrument

Each probe maps to a specific prediction from Phase 3. **Change one variable
at a time.**

Tool preference:

1. **Debugger or REPL inspection** where the environment supports it. One
   breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix — `[DEBUG-a4f2]`. Cleanup becomes
a single grep. Untagged probes survive the session; tagged ones die.

**Performance branch.** For regressions in speed, logs are usually the wrong
instrument. Establish a baseline measurement (timing harness, profiler, query
plan), then bisect. Measure first, fix second.

## Phase 5: Fix with a regression test

Write the regression test **before the fix** — but only if a **correct seam**
exists for it.

A correct seam exercises the real bug pattern as it occurs at the call site.
If the only available seam is too shallow — a single-caller test when the bug
needs several, a unit test that cannot replicate the triggering chain — a test
there gives false confidence.

**If no correct seam exists, that is itself the finding.** Say so. The
architecture is preventing the bug from being locked down, and that outranks
the individual fix.

With a correct seam:

1. Turn the minimised repro into a failing test there.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 loop against the original, un-minimised scenario.

## Phase 6: Cleanup

Required before claiming done:

- Original repro no longer reproduces — re-run the Phase 1 loop
- Regression test passes, or the absence of a seam is written down
- All `[DEBUG-...]` instrumentation removed — grep the prefix
- Throwaway harnesses deleted, or moved somewhere clearly marked
- The hypothesis that proved correct is stated in the commit or PR body, so
  the next person debugging this area learns from it

Claiming a fix works is a completion claim: `me:verification-before-completion`
applies, and the Phase 1 loop is the evidence.

## Red Flags

Stop if you catch yourself doing any of these:

| Rationalisation | What it actually means |
| --- | --- |
| "I can see the bug just by reading the code" | You have a theory, not a signal. Build the loop; theories are free and wrong. |
| "The loop is flaky but good enough" | A flaky loop cannot tell a fix from luck. Tighten it first. |
| "This is obviously a race condition" | That is hypothesis #1 of 5, untested. Write the other four. |
| "I'll clean up the debug logs later" | Tag them now or they ship. |
| "The test passes, so it's fixed" | Re-run the original un-minimised repro. A passing minimal test can miss the real path. |
