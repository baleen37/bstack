# Evidence Standards

## Cross-Reference Threshold

**Verify with 3+ independent sources before concluding.**

## Insufficient Evidence Examples

❌ Examples that don't meet standards:

- "Read the code, it does X" → Which files? Which lines?
- "This approach works" → Tested? Verified?
- "Confident based on experience" → Experience ≠ verification
- Single source without verification → Cross-reference required

## Sufficient Evidence Examples

✅ Examples that meet standards:

- "lib/state.sh:45-52 validates session_id with regex `^[a-zA-Z0-9_-]+$`"
- "Tested with empty session_id → exits with error code 1"
- "Verified against official docs v5.3.0"
- Cross-referenced across 3+ sources with consistent findings

## Negative Evidence

Explicitly document what's NOT there:

- "No 'prompt' or 'agent' hook type examples found in codebase"
- "No locking mechanism exists despite concurrent execution"
- "No test coverage for parallel execution scenarios"

## Red Flags - STOP

These thoughts mean you're rushing or rationalizing:

### Skipping Verification

- "Read enough, let's summarize" → Evidence ≠ volume. Quality sources matter.
- "Logic makes sense" → Theory ≠ reality. Test it.
- "No time to verify" → Verification prevents rework.

### Insufficient Evidence

- "I understand the pattern" → Verify in current codebase context.
- "This is standard practice" → Standard for what? When? Prove it.
- "Good enough to proceed" → Evidence-based or assumption-based?

### Premature Conclusions

- "Findings align with expectation" → Confirmation bias risk. Look for contradictions.
- "No issues found" → Did you look for edge cases? Error paths? Negative evidence?
- "Ready to implement" → Are findings documented with sources?
- "Seen enough examples" → Keep verifying. Patterns may have unseen edge cases.

**Research means evidence-first. Always.**

## Common Evidence Mistakes

| Mistake | Fix |
| :--- | :--- |
| Single-source reliance | Cross-reference findings from multiple sources (3+ minimum) |
| No documentation | Document as you go with file paths/line numbers or URLs |
| Skipping edge cases | Explicitly check error paths and boundaries |
| Logical inference only | Run code, verify actual behavior |
| Premature recommendations | Findings first, recommendations second |
| Ignoring negative evidence | Explicitly document what's NOT there or NOT working |
| Assuming tests cover everything | Tests may miss race conditions, parallel execution |
| Schema without verification | Schema defines structure, not behavior. Test it. |
| Codebase-only research | Check official docs for version-specific behavior |
