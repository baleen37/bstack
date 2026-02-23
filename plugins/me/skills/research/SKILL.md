---
name: research
description: Use when exploring unfamiliar codebases, investigating bugs, or learning new technologies before acting
---

# Research

## Overview

Evidence-based exploration: **Observe → Explore → Verify → Summarize**.

**Core principle:** 30 minutes of targeted research beats hours of wrong implementation.

**CRITICAL: Verification is MANDATORY.** Reading code is NOT research. Testing behavior IS research.

## When to Use

```text
Need to understand before acting?
    │
    ├─ Unfamiliar codebase/architecture? → YES
    ├─ Investigating bug or unexpected behavior? → YES
    ├─ Learning new technology/framework? → YES
    └─ Simple, well-understood task? → NO (just do it)
```

**Use for:**

- Understanding requirements before implementation
- Investigating root causes
- Learning new domains
- Comparing approaches

**Don't use for:**

- Routine fixes in familiar code
- Well-documented APIs you know
- Simple mechanical changes

## Quick Reference

| Phase | Codebase-only | Web-only | Hybrid |
| :--- | :--- | :--- | :--- |
| **Observe** | Clarify scope, identify files | Clarify question, note version | Define independent scopes |
| **Explore** | Task: Explore agent | Task: web-researcher agent | Task: Explore + web-researcher (parallel) |
| **Verify** | Run code, cross-reference files | Cross-check multiple sources | Compare code vs docs findings |
| **Summarize** | File paths, line numbers | URLs, version info | Combined evidence from both |

## Subagent Strategy

### Why Subagents?

Research benefits from subagent delegation:

- **Fresh context** per research question (no contamination)
- **Parallel execution** of independent research tracks
- **Cost efficiency** using Haiku for focused tasks
- **Focused scope** reduces confusion and improves accuracy

### Model Selection

| Task Type | Model | Rationale |
| :--- | :--- | :--- |
| Codebase exploration | **haiku** (Explore agent default) | Fast, cheap, sufficient for code search |
| Web research | **haiku** (web-researcher agent) | Quick information gathering |
| Complex synthesis | **sonnet** (main session) | Analysis requires deeper reasoning |
| Verification requiring execution | **sonnet** | May need to run code/analyze |

**Rule of thumb:** Use Haiku for subagent research tasks. Reserve Sonnet for final synthesis and complex verification.

## Research Scenarios and Tool Selection

| Scenario | Tool Command | Model | When to Use |
| :--- | :--- | :--- | :--- |
| **Codebase-only** | `Task tool: subagent_type="Explore"` | haiku | Unfamiliar architecture, existing bugs, code patterns |
| **Web-only** | `Task tool: subagent_type="me:web-researcher"` | haiku | New tech, official docs, version-specific info |
| **Hybrid** | Parallel: Explore + web-researcher | haiku (both) | Code vs docs comparison, version mismatches |

## Tool Usage Guidelines

### For Codebase Research

**MANDATORY: ALWAYS use Explore agent for codebase exploration.**

**DO:**

```markdown
Task tool with subagent_type="Explore", description="Search codebase for X implementation patterns"
```

**NEVER:**

- Manual Grep/Glob for exploration - ALWAYS delegate to Explore agent
- Use Explore agent for web search (it has no web tools)
- Use general-purpose agent when Explore is specialized for codebase
- Do research yourself - subagents provide fresh context and parallel execution

### For Web Research

**DO:**

```markdown
Task tool with subagent_type="me:web-researcher", description="Find official documentation for X framework"
```

**DON'T:**

- Use built-in WebSearch tool (use web-researcher agent instead)
- Skip version context (always specify version when relevant)
- Rely on single source (web-researcher will cross-reference)

### For Hybrid Research (Parallel Pattern)

When you have independent codebase AND web research questions:

```markdown
# Define independent scopes
Subtask A: "How is authentication implemented in our codebase?"
Subtask B: "What are the official authentication patterns for Framework X?"

# Dispatch in parallel (use Task tool in single message with multiple Task calls)
Task 1: subagent_type="Explore", description="Search codebase for authentication implementation"
Task 2: subagent_type="me:web-researcher", description="Find Framework X official authentication patterns"

# Synthesize findings
Compare: Our implementation vs official docs
Identify: Gaps, anti-patterns, version mismatches
```

## Evidence Standards

**Cross-reference threshold:** Verify with 3+ independent sources before concluding.

**VERIFICATION REQUIREMENT:** Reading code is NOT sufficient. You MUST verify behavior through:

- Running the code
- Testing with actual inputs
- Cross-referencing official documentation
- Checking multiple independent sources

**Insufficient evidence:**

- "Read the code, it does X" → Did you RUN it? Did you TEST it?
- "This approach works" → Tested? Verified? With what inputs?
- "Confident based on experience" → Experience ≠ verification
- Single source without verification → Cross-reference required
- Code reading only → Must verify actual behavior
- "The code shows..." → What does EXECUTION show?

**Sufficient evidence:**

- "lib/state.sh:45-52 validates session_id with regex"

  `^[a-zA-Z0-9_-]+$`

  "+ Tested with empty session_id → exits with error code 1"
- "Verified against official docs v5.3.0" + "Tested with production data"
- Cross-referenced across 3+ sources with consistent findings + verified with execution

**Evidence hierarchy (strongest to weakest):**

1. **Tested behavior** - Ran code, observed results
2. **Official documentation** - Version-specific, authoritative
3. **Cross-referenced patterns** - Multiple sources agree
4. **Code reading** - NOT sufficient alone, must verify

**Negative evidence:** Explicitly document what's NOT there:

- "No 'prompt' or 'agent' hook type examples found in codebase"
- "No locking mechanism exists despite concurrent execution"
- "No test coverage for parallel execution scenarios"
- "Searched for X pattern across Y files - none found"

## Rationalization (REJECT ALL)

| Excuse | Reality |
| :--- | :--- |
| "User wants fast answer" | Fast right > fast wrong. Rework takes longer. |
| "I'll search quickly myself" | Manual search = slow + single-perspective. Use subagents. |
| "Sequential is fine" | Independent research = parallel. Don't waste time. |
| "General-purpose agent is safer" | Specialized agents (Explore, web-researcher) are more focused. |
| "This is straightforward" | Simple still requires verification. Don't guess. |
| "Confident based on experience" | Confidence ≠ correctness. Verify with evidence. |
| "Read the code, that's enough" | Reading ≠ verification. Must RUN and TEST. |
| "The code shows X" | Code ≠ behavior. What does EXECUTION show? |
| "Logic is sound" | Logical ≠ correct. Reality beats theory. |
| "예/Yes - [assertion]" | Confident assertion without testing = speculation. |
| "심각한 [problem] 발견" | Without testing? That's speculation, not discovery. |
| "This part is fine" | How do you know? Verify, don't assume. |
| "I've seen enough to speculate" | Speculation without evidence is guessing. |
| "가능한 [X]는..." | Listing possibilities without evidence = guessing. |
| "Simple read-write can't be broken" | Simple operations have race conditions without synchronization. |
| "Race conditions are rare" | Rare bugs become common at scale. Verify, don't assume. |
| "Found one good example" | Single source = insufficient. Cross-reference 3+ sources. |
| "Official docs are probably similar" | Probably ≠ verified. Check actual documentation. |
| "I've seen enough examples" | Patterns may have edge cases you haven't seen. Keep verifying. |
| "The schema tells me everything" | Schema defines structure, not behavior. Test it. |
| "Codebase is clear enough" | Codebase ≠ complete picture. Check official docs too. |
| "Don't need docs for codebase research" | Even codebase research needs external verification. |

## Red Flags - STOP

These thoughts mean you're rushing or rationalizing:

### Using Wrong Tools (CRITICAL)

- Manual Grep/Glob for exploration → Use Explore agent ALWAYS
- Direct file reading for research → Delegate to subagents
- Doing research yourself → Fresh context per subagent > contaminated main context
- General-purpose when specialized available → Use Explore or web-researcher

### Subagent Anti-patterns

- "I'll search myself" → Use subagents for research. You synthesize.
- "Sequential is fine" → Independent research = parallel execution.
- "Sonnet for everything" → Haiku sufficient for focused research tasks.
- "Explore agent can search web" → Explore has NO web tools.
- "General-purpose is safer" → Specialized agents (Explore, web-researcher) are more focused.

### Skipping Verification (CRITICAL VIOLATION)

- "Read code, that's research" → Reading ≠ verification. Must RUN and TEST.
- "The code shows X" → Code shows intent. Execution shows reality. TEST IT.
- "Read enough, let's summarize" → Without testing = speculation, not research.
- "Logic makes sense" → Theory ≠ reality. Test it.
- "No time to verify" → Verification prevents rework. Always cheaper upfront.
- "Code is clear enough" → Clear code can have unclear behavior. Verify.
- "심각한 [X] 발견" without testing → Speculation dressed as discovery.
- Starting "가능한" or "possible" sections → Listing guesses, not findings.

### Insufficient Evidence

- "I understand the pattern" → Verify in current codebase context.
- "This is standard practice" → Standard for what? When? Prove it.
- "Good enough to proceed" → Evidence-based or assumption-based?
- "Found one good source" → Single source = insufficient. Need 3+.
- "Confident this is the issue" → Assertion without testing = speculation.
- "Codebase-only research is enough" → Even codebase needs external verification.
- "The code documents itself" → Code + official docs + testing = complete picture.

### Premature Conclusions

- "Findings align with expectation" → Confirmation bias risk. Look for contradictions.
- "No issues found" → Did you look for edge cases? Error paths? Negative evidence?
- "Ready to implement" → Are findings documented with sources?
- "Seen enough examples" → Keep verifying. Patterns may have unseen edge cases.
- Starting "버그 추측" section → Speculation before full research = wrong approach.
- "가능한 버그는..." → Listing possible bugs without evidence = guessing.

**Research means evidence-first. Always.**

**Reading code is NOT research. Verification is research.**

## Common Mistakes

| Mistake | Fix |
| :--- | :--- |
| Manual Grep/Glob for exploration | ALWAYS use Explore agent - never do direct file search |
| Doing research yourself | Delegate to subagents - fresh context per question |
| Not using subagents for research | Delegate to Explore/web-researcher - faster, cheaper, fresh context |
| Sequential hybrid research | Run codebase + web research in parallel when independent |
| Using Sonnet for simple research | Haiku is sufficient and cost-efficient for subagent tasks |
| Reading code without verification | Reading ≠ research. Must RUN code, TEST behavior, verify results |
| "The code shows X" conclusions | Code shows intent, execution shows reality. TEST IT. |
| Single-source reliance | Cross-reference findings from multiple sources (3+ minimum) |
| Confident assertions without testing | "심각한 [X] 발견" without testing = speculation |
| Speculation sections | "가능한 버그는...", "possible bugs" = guessing, not research |
| No documentation | Document as you go with file paths/line numbers or URLs |
| Skipping edge cases | Explicitly check error paths and boundaries |
| Logical inference only | Run code, verify actual behavior |
| Premature recommendations | Findings first, recommendations second |
| Ignoring negative evidence | Explicitly document what's NOT there or NOT working |
| Assuming tests cover everything | Tests may miss race conditions, parallel execution - verify |
| Schema without verification | Schema defines structure, not behavior. Test it. |
| Codebase-only research | Even codebase research needs official docs cross-reference |
| "Pattern is clear from code" | Code reading ≠ understanding behavior. Test and verify. |

## Output Format

```markdown
# Research Findings: [topic]

## Context
[Original question and research scope]

## Key Findings
[Primary discoveries with specific file paths and line numbers]

## Evidence Summary
- Source 1: [file:line or URL] - [specific quote or observation]
- Source 2: [file:line or URL] - [specific quote or observation]
- Source 3: [file:line or URL] - [specific quote or observation]

## Verification
[Test performed, actual results, edge cases checked]

## Open Questions
[Unresolved items requiring further research]

## Confidence Level
High / Medium / Low with rationale

## Recommendations
[Actionable next steps based on findings]
```
