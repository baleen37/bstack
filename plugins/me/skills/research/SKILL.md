---
name: research
description: Use when external facts, documentation, standards, papers, releases, technology comparisons, recommendations, or other current reference material must be found or verified
---

# Research

Keep source discovery and discarded leads out of the parent context.

## Scope

Before any other action, reject codebase exploration and local bug
investigation as outside this skill. Respond immediately without reading
repository files, searching, browsing, or delegating.

## Delegate

When source discovery is needed, invoke exactly one
`Agent: subagent_type="me:researcher"` with the complete question. The parent
must not search, browse, or otherwise discover sources itself. Do not split one
request across multiple researchers.

Explicitly select the most token-efficient available model that can meet the
evidence bar. Do not rely on an inherited default. Escalate only after the
result fails a stated quality requirement.

Give the researcher:

- the question and decision it must support,
- freshness or date constraints,
- the evidence bar,
- the required output fields.

If the user supplies one exact source and only asks to read it, read it
directly. Any source discovery belongs in the researcher.

Use the returned synthesis without repeating the investigation. Spot-check a
citation only when the claim is material, suspicious, or high-risk.

## Result

Return the direct answer, claim-bearing sources, and material gaps. Keep raw
search results, dead ends, and unused sources inside the researcher context.
