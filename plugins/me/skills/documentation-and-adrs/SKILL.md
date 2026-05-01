---
name: documentation-and-adrs
description: Architecture Decision Records, API docs, and inline documentation standards — document the why. Use when making architectural decisions, changing APIs, or shipping features.
---

# Documentation and ADRs

## Overview

Document the **why**, not the what. Code shows what; docs explain why this and not the alternatives. Future readers (including future-you) need the reasoning, not a restatement of the diff.

## Architecture Decision Records (ADRs)

One short markdown file per significant decision. Format:

```
# ADR-NNN: <Title>

## Status
Proposed | Accepted | Superseded by ADR-XXX

## Context
What problem? What constraints? What did we know at the time?

## Decision
What we chose.

## Consequences
What this enables, what it costs, what it forecloses.

## Alternatives Considered
What else we looked at and why we didn't pick it.
```

Write an ADR when: choosing a framework, picking a data model, drawing a service boundary, or making any choice that's expensive to reverse.

## API Documentation

- **Contracts before prose**: schema, types, examples first.
- **Show, don't tell**: a working example beats three paragraphs.
- **Errors are part of the API**: document failure modes, not just success.

## Inline Comments

Default to no comment. Write one only when the **why** is non-obvious:

- A hidden constraint (rate limit, ordering requirement).
- A workaround for a specific bug (link to the issue).
- A subtle invariant a future editor might break.

Don't restate the code. Don't reference the current task or PR.

## Anti-patterns

- ADRs written after the fact to justify a decision.
- API docs that list method signatures and nothing else.
- Comments that say what the next line does.
- README that's a wishlist, not a description of the current state.
