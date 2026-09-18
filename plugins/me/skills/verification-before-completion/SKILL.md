---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
---

# Verification Before Completion

## Overview

**Core principle:** Evidence before claims.

A completion claim is a factual report about the state of the code. Reporting it without having
looked misstates that state to the person relying on it — which is the cost this skill exists to
avoid, whatever wording the claim arrives in.

## Which skill to use

- `verification-before-completion` — the gate you pass before *claiming* anything is done. Applies
  to every completion claim, in any wording.
- `/verify` — the task of checking whether one change behaves as intended, producing a
  PASS/PARTIAL/FAIL report. That report is itself a claim, so this gate applies to it.
- `/e2e-scenario-testing` — drive a running app through its real interface, one scenario.

## The rule

Do not claim something passes until you have run its verification in this message.

A previous run does not carry over: the code has changed since, which is the reason you are
claiming anything at all.

## The gate function

```
BEFORE claiming any status or expressing satisfaction:

1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code, count failures
4. VERIFY: Does output confirm the claim?
   - If NO: State actual status with evidence
   - If YES: State claim WITH evidence
5. ONLY THEN: Make the claim
```

## Common failures

| Claim | Requires | Not sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Signals you are about to skip the gate

- Reaching for "should", "probably", "seems to"
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit, push, or open a PR without running anything
- Taking an agent's success report at face value
- Leaning on a partial check to cover the whole claim
- Any wording that implies success when nothing has been run

## Reasons that do not hold

| Reason | Why it doesn't hold |
|--------|---------------------|
| "Should work now" | Run the verification |
| "I'm confident" | Confidence isn't evidence |
| "Just this once" | The claim is wrong in exactly the same way |
| "Linter passed" | A linter doesn't check compilation |
| "Agent said success" | Verify independently |
| "Partial check is enough" | A partial check proves only its part |
| "Different words, so the rule doesn't apply" | The claim is what matters, not its phrasing |

## Key patterns

**Tests:**
```
✅ [Run test command] [See: 34/34 pass] "All tests pass"
❌ "Should pass now" / "Looks correct"
```

**Regression tests (TDD red-green):**
```
✅ Write → Run (pass) → Revert fix → Run (must fail) → Restore → Run (pass)
❌ "I've written a regression test" (without red-green verification)
```

**Build:**
```
✅ [Run build] [See: exit 0] "Build passes"
❌ "Linter passed" (a linter doesn't check compilation)
```

**Requirements:**
```
✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
❌ "Tests pass, phase complete"
```

**Agent delegation:**
```
✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
❌ Trust the agent's report
```

## When to apply

Before:

- any claim of success or completion, in any wording
- any expression of satisfaction about the work's state
- committing, opening a PR, or calling a task done
- moving to the next task
- delegating to agents

The rule tracks what the claim asserts, not the words it uses — a paraphrase or an implication of
success carries the same weight as the exact phrase.
