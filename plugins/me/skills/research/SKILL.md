---
name: research
description: Use when external facts, documentation, standards, papers, releases, technology comparisons, recommendations, or other current reference material must be found or verified
---

# Research

Classify the request before using tools.

## Route

- Local codebase exploration or local bug investigation is outside this skill.
  Reply with that boundary without reading files, browsing, or delegating.
- If the user supplied one exact source and only wants it inspected, use a
  direct fetch or open action such as `curl` on only that URL. Do not use any
  search tool or delegate.
- When source discovery or comparison is needed, send the complete request once
  to `me:researcher`. Do not fan out.

Give the researcher the question, decision to support, freshness constraint,
evidence bar, and required output. Use the lowest-cost capable option available;
escalate only after a stated quality requirement fails.

If delegation is unavailable or fails, read `../../agents/researcher.md` and
apply its external, read-only contract directly. The exact-source path follows
the same evidence contract without discovery.

## Return

Use the research result without repeating its investigation. Return the direct
answer with citations next to supported claims and only material uncertainty.
Keep search logs, dead ends, unused sources, and duplicated evidence out of the
response.
