---
name: competitive-agents
description: Use when two agents should compete on the same task with judge synthesis
---

# Competitive Agents

## Overview

Dispatch two independent subagents to solve the same task in parallel. Both know
they're competing. A third judge agent analyzes both solutions and synthesizes
the best elements into a superior combined result.

## When to Use

- User explicitly requests competitive/parallel approaches
- A task could benefit from exploring multiple solutions simultaneously
- You want to reduce bias from a single agent's perspective

## When NOT to Use

- Simple, well-defined tasks with one obvious approach
- Tasks requiring sequential steps (not parallelizable)
- When speed matters more than solution quality (this uses 3x the compute)

## Workflow

1. Extract the task from the user's request
2. Dispatch 2 subagents in parallel (single message, 2 Task tool calls)
3. Wait for both results
4. Dispatch judge agent with both results
5. Present synthesized result to user

## Competitor Prompt Template

Use this as the prompt for each of the two competing subagents:

~~~text
You are competing against another agent to solve the same task.
The better solution will be selected. Give your absolute best effort.

## Task
{task content from user}

## Requirements
- Provide a complete, well-reasoned solution
- Explain your approach and key decisions
- Consider trade-offs and alternatives you considered
~~~

Both agents use `subagent_type: "general-purpose"`.

## Judge Prompt Template

Use this as the prompt for the judge agent, after both competitors complete:

~~~text
You are judging two competing solutions to the same task.
Your job is to synthesize the best elements into a superior combined solution.

## Original Task
{original task from user}

## Solution A
{result from first competitor}

## Solution B
{result from second competitor}

## Instructions
1. Analyze strengths and weaknesses of each solution
2. Synthesize the best elements into a superior combined solution
3. Explain what you took from each and why

Format your response as:

### Analysis
**Solution A:** [strengths] / [weaknesses]
**Solution B:** [strengths] / [weaknesses]

### Synthesized Solution
[your combined best solution]

### Rationale
[what you took from each solution and why]
~~~

The judge also uses `subagent_type: "general-purpose"`.

## Execution Example

In a single message, dispatch both competitors:

~~~text
Task call 1: description="Competitor A", subagent_type="general-purpose", prompt=<competitor template with task>
Task call 2: description="Competitor B", subagent_type="general-purpose", prompt=<competitor template with task>
~~~

After both return, dispatch the judge:

~~~text
Task call 3: description="Judge synthesis", subagent_type="general-purpose", prompt=<judge template with both results>
~~~

Present the judge's synthesized result to the user.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Running judge before both complete | Always wait for both competitors (foreground mode) |
| Giving competitors different prompts | Both must receive identical task content |
| Skipping the judge | Always synthesize - even if one solution seems clearly better, the other may have valuable elements |
| Using background mode | Use foreground so you can pass results to judge |
