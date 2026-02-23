# Research Skill Test Scenarios

## Purpose

Pressure scenarios to identify violations and rationalizations when research skill is absent or present.

## Scenario 1: Time Pressure + Familiar Domain

**Setup:**

- User asks: "How does authentication work in this codebase? I need to fix a bug quickly."
- Codebase has auth implementation scattered across 5+ files
- Agent might be tempted to give quick answer from 1-2 files

**Expected Violations (without skill):**

- Single-file analysis without exploring full auth flow
- No verification of actual behavior (just reading code)
- Skipping edge cases
- No documentation of file paths/line numbers

**Rationalizations to watch for:**

- "This is straightforward, just need to check X"
- "User wants fast answer"
- "Code is clear, no need to test"

**Success Criteria (with skill):**

- Uses Explore agent for comprehensive search
- Identifies ALL auth-related files
- Verifies behavior (not just reads code)
- Documents file:line references

---

## Scenario 2: Incomplete Information + Confidence

**Setup:**

- User asks: "Does our session management handle race conditions?"
- No explicit locking visible in code
- Agent might be confident "simple read-write can't be broken"

**Expected Violations (without skill):**

- Assumes no race condition without verification
- Logical inference without testing
- Single-source analysis (just reading the implementation)
- No negative evidence documentation

**Rationalizations to watch for:**

- "Simple read-write can't be broken"
- "Race conditions are rare"
- "Logic is sound"
- "Confident based on experience"

**Success Criteria (with skill):**

- Explicitly searches for locking/synchronization
- Tests concurrent scenarios or documents inability to test
- Cross-references with multiple sources
- Documents negative evidence ("No locking mechanism found")

---

## Scenario 3: Single Source + Time Pressure

**Setup:**

- User asks: "How do I use feature X in library Y?"
- Agent finds one good example in first search result
- Temptation to stop after single source

**Expected Violations (without skill):**

- Single-source reliance
- No cross-referencing
- Skipping official docs
- No version verification

**Rationalizations to watch for:**

- "This example is clear enough"
- "No time to check multiple sources"
- "First result is usually best"

**Success Criteria (with skill):**

- Searches 3+ independent sources
- Checks official documentation
- Verifies version compatibility
- Documents all sources with URLs

---

## Scenario 4: Hybrid Research - Tool Selection

**Setup:**

- User asks: "How should we implement feature X? Check our codebase patterns and official docs."
- Requires both codebase exploration AND web research
- Independent research tracks that can run in parallel

**Expected Violations (without skill):**

- Sequential execution (codebase first, then web)
- Wrong tool selection (Grep/Glob instead of Explore agent)
- Using Explore agent for web search (it has no web tools)
- Using Sonnet for simple research tasks

**Rationalizations to watch for:**

- "Sequential is fine, not much work"
- "I'll search myself, faster than subagent"
- "Explore agent can probably search web too"
- "Sonnet is safer for everything"

**Success Criteria (with skill):**

- Recognizes independent research tracks
- Dispatches Explore + web-researcher in parallel
- Uses Haiku for subagent tasks
- Synthesizes findings from both sources

---

## Scenario 5: Premature Conclusion

**Setup:**

- User asks: "Investigate why tests are failing"
- Agent finds one failing test, sees obvious issue
- Temptation to conclude without checking other tests

**Expected Violations (without skill):**

- Stops after finding first issue
- No edge case exploration
- No verification of fix
- Premature recommendations

**Rationalizations to watch for:**

- "Found the issue, this must be it"
- "Ready to implement fix"
- "No need to check other tests"
- "Logic makes sense"

**Success Criteria (with skill):**

- Checks ALL failing tests
- Explores edge cases and error paths
- Verifies hypothesis before concluding
- Documents findings before recommendations

---

## Testing Protocol

### Baseline (RED Phase)

1. Run scenario WITHOUT research skill available
2. Document exact agent behavior verbatim
3. Identify violation patterns
4. Capture rationalizations word-for-word

### With Skill (GREEN Phase)

1. Run same scenario WITH research skill
2. Verify agent follows Observe → Explore → Verify → Summarize
3. Check for proper tool usage (subagents, parallel execution)
4. Confirm evidence standards met

### Refactor Phase

1. Identify NEW rationalizations
2. Add explicit counters to skill
3. Re-test until bulletproof

## Success Metrics

- [ ] Agent uses subagents for research (not direct Grep/Glob)
- [ ] Parallel execution for independent research tracks
- [ ] 3+ source cross-referencing
- [ ] Explicit documentation (file:line or URLs)
- [ ] Verification before conclusions
- [ ] Negative evidence documented
- [ ] No rationalizations from table
