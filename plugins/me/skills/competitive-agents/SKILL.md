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

## Red Flags - Skill Still Applies

Don't skip just because:

- Task seems "simple" (simplicity ≠ obvious solution)
- You think one approach is "best" (that's exactly the bias to avoid)

If multiple valid approaches exist, use this skill.

## Workflow

1. **Clarify if needed** — if the task is ambiguous, ask the user before dispatching
2. Dispatch 2 subagents in parallel (single message, 2 Task tool calls)
3. Wait for both results
4. **You (main agent) synthesize** the best elements directly — no third subagent
5. Present synthesized result to user

## Competitor Prompt Template

Each competitor gets the **same task** but a **different constraint** to force divergent solutions:

**Competitor A:**

~~~text
You are competing against another agent to solve the same task.
The better solution will be selected. Give your absolute best effort.

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
You are competing against another agent to solve the same task.
The better solution will be selected. Give your absolute best effort.

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

## Execution

Dispatch both competitors in a **single message** (parallel):

~~~text
Task call 1: description="Competitor A - simplicity", subagent_type="general-purpose"
Task call 2: description="Competitor B - completeness", subagent_type="general-purpose"
~~~

After both return, synthesize directly as the main agent (see Synthesis section above).

## Common Mistakes

| Mistake | Fix |
| ------- | --- |
| Both competitors produce identical solutions | Use the constraint prompts above to force divergence |
| Synthesizing before both competitors complete | Use foreground mode, wait for both |
| Skipping synthesis | Always synthesize — even if one seems clearly better |
| Dispatching a judge subagent | Main agent synthesizes directly — no third Task call needed |
| Dispatching on an unclear task | Clarify with user first (workflow step 1) |
| Skipping because task seems "simple" | Simplicity of description ≠ obvious solution |
