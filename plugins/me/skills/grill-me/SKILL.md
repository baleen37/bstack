---
name: grill-me
description: Interview the user in rounds until every decision in a plan or design is settled. Use when the user wants to be grilled, when another skill asks for grilling, or when decisions must be resolved before anything is written. Writes no spec or plan.
---

# Grill Me

Resolve every decision in a plan or design by interviewing in rounds. The
output is a shared understanding, not a document. When the frontier is empty,
summarize the settled decisions and return to whoever called you.

## Establish shared understanding

1. Identify the intended outcome, who it is for, and what success looks like.
   When this is missing, ask about it first.
2. Reflect the outcome, constraints, and success criteria briefly. Separate
   what your partner said from your assumptions and invite correction.

When the request already supplies these, reflect them instead of asking again.

## Interview in rounds

Map the work as a **design tree**: every decision branches into the decisions
that hang off it.

The **frontier** is every decision whose prerequisites are already settled —
the questions you can ask *now* without guessing at answers you haven't heard
yet. Ask the whole frontier in one round. Number each question and give your
recommended answer. Then wait.

A question whose answer depends on another question still open in this round
belongs to a later round.

Each round of answers reshapes the tree: settled decisions unblock what
depended on them. Recompute the frontier and ask the next round.

Format each round like this:

```
❓ **Q1** - **<question title>**: <question body, may include options>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body>

➡️ <your recommended answer>
```

**Facts are your job; decisions are theirs.** When a question needs a fact from
the environment — what a file contains, what version is pinned, whether an API
exists — find it yourself rather than asking. Dispatch a subagent if the lookup
is broad. Only the questions downstream of a running lookup wait.

## Project language

- Follow `CONTEXT-MAP.md` when present to find the relevant `CONTEXT.md`, and
  read related ADRs before proposing domain terms or decisions.
- When a term in the request conflicts with the glossary or is ambiguous,
  resolve its meaning in the next round.
- When a new term is agreed, use `me:domain-modeling` to record it. Propose an
  ADR only for a decision that is hard to reverse, surprising without its
  rationale, and has real alternatives.

## Done

The session is done when the frontier is empty: every branch visited, nothing
silently assumed. Then list the settled decisions in one short block. Do not
write a spec, a plan, or code. If your partner wants a document next, they
choose it.
