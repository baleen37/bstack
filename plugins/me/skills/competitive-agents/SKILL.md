---
name: competitive-agents
description: Use when designing systems, architectures, or APIs, when multiple valid approaches exist with no single obvious answer, or when user explicitly requests parallel/competing solutions
---

# Competitive Agents

## Overview

Dispatch two independent subagents to solve the same task from different angles.
The main agent then synthesizes the best elements into a superior combined result.

## When to Use

- Designing systems, architectures, or APIs
- Problems with multiple valid approaches (no single obvious answer)
- User explicitly requests competitive/parallel approaches
- You want to reduce single-agent bias

## When NOT to Use

- Purely mechanical tasks (rename variable, fix typo, add import)
- Tasks requiring sequential steps (not parallelizable)
- Task is unclear — clarify with user first, then decide

## Workflow

1. **Clarify if needed** — if the task is ambiguous, ask the user before dispatching
2. Dispatch 2 subagents in parallel (single message, 2 Agent tool calls)
3. Wait for both completion notifications
4. **You (main agent) synthesize** the best elements directly — no third subagent
5. Present synthesized result to user

## Competitor Prompt Template

Each competitor gets the **same task** but a **different constraint**; without the constraint both
tend to return the same solution:

**Competitor A:**

~~~text
YOUR CONSTRAINT: Prioritize simplicity and minimalism. Fewer moving parts wins.

## Task
{task content from user}

## Requirements
- Provide a complete, well-reasoned solution
- Explain your approach and key decisions
- Consider trade-offs and alternatives you rejected
~~~

**Competitor B:**

~~~text
YOUR CONSTRAINT: Prioritize completeness and extensibility. Cover more cases and future needs.

## Task
{task content from user}

## Requirements
- Provide a complete, well-reasoned solution
- Explain your approach and key decisions
- Consider trade-offs and alternatives you rejected
~~~

Both use `subagent_type: "general-purpose"`.

## Synthesis (Main Agent)

After both competitors complete, **you** synthesize directly. No subagent needed — you already have both results in context.

Analyze and present in this format:

### Analysis
**Solution A:** [strengths] / [weaknesses]
**Solution B:** [strengths] / [weaknesses]

### Synthesized Solution
[combined best solution]

### Rationale
[what you took from each and why]
