# Rationalization Guide

## REJECT ALL EXCUSES

| Excuse | Reality |
| :--- | :--- |
| "Code review is enough" | Code ≠ behavior. Test it. |
| "User wants fast answer" | Fast right > fast wrong. Rework takes longer. |
| "This is straightforward" | Simple still requires verification. Don't guess. |
| "Confident based on experience" | Confidence ≠ correctness. Verify with evidence. |
| "Too much to read" | 30 min targeted research vs hours of rework. |
| "Logic is sound" | Logical ≠ correct. Reality beats theory. |
| "Tests pass, must be user error" | Tests may not cover your scenario. Verify actual conditions. |
| "Simple read-write can't be broken" | Simple operations have race conditions without synchronization. |
| "Race conditions are rare" | Rare bugs become common at scale. Verify, don't assume. |
| "Just add a lock" | Locks add complexity. Verify the problem exists first. |
| "I've seen enough examples" | Patterns may have edge cases you haven't seen. Keep verifying. |
| "The schema tells me everything" | Schema defines structure, not behavior. Test it. |

## The Cost of Skipping Research

**30 minutes of targeted research beats hours of wrong implementation.**

When you're tempted to skip research:

1. Estimate time to research properly
2. Estimate time to rework if wrong
3. Choose research every time

## Research vs. Speed

### Fast Right > Fast Wrong

- Wrong implementation wastes more time than research
- Rework requires context switching (expensive)
- Failed deployments have cascading costs
- Lost trust is hard to rebuild

## Experience vs. Evidence

**Experience informs where to look. Evidence informs what to do.**

- Experience helps you find relevant code faster
- Experience suggests likely patterns
- **But experience does NOT replace verification**
- Current codebase may differ from past experience

## When to Stop Rationalizing

If you catch yourself thinking:

- "Probably works"
- "Should be fine"
- "Most likely"
- "I think"
- "Based on past experience"

→ **STOP. Get evidence.**
