---
name: research
description: Use when exploring unfamiliar codebases, investigating bugs, or learning new technologies before acting
---

# Research

Evidence-based exploration: **Observe → Explore → Verify → Summarize**.

**Reading code is NOT research. Testing behavior IS research.**

## Tool Selection

| Scenario | Tool | Note |
| :--- | :--- | :--- |
| Codebase | `Task: subagent_type="Explore"` | NEVER manual Grep/Glob |
| Web | `Task: subagent_type="core:web-researcher"` | haiku built-in |
| Hybrid | Both in parallel | synthesize in main session |

Use `model="haiku"` for simple Explore tasks.

## Evidence Standards

- **3+ independent sources** before concluding
- **Sufficient:** `lib/state.sh:45 validates regex + tested empty input → exits code 1`
- **Insufficient:** "Read the code, it does X" — did you RUN it?
- **Negative evidence:** document what's NOT there

## Red Flags — STOP

- "Read code, that's enough" → must RUN and TEST
- "Found one good source" → need 3+
- "Confident based on experience" → experience ≠ evidence
- Listing "possible bugs" without testing → speculation

