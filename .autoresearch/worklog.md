# Worklog: Ralph Plugin Optimization

## Session Info
- **Goal:** Optimize Ralph plugin for simplicity and token efficiency
- **Branch:** autoresearch/ralph-improve-20260403
- **Started:** 2026-04-03
- **Primary Metric:** skill_bytes (SKILL.md byte count, lower is better)

## Current State
- ralph/SKILL.md: 2914 bytes, 90 lines
- ralph-cancel/SKILL.md: 696 bytes, 23 lines
- ralph-persist.ts: 3747 bytes, 138 lines
- Total: 7357 bytes

## Key Insights
- SKILL.md is loaded into LLM context — every byte matters
- Hook runs in Bun (OS level) — doesn't cost tokens but should be clean
- Plugin is already well-designed, optimization is about compression not redesign
- Web best practices suggest: minimal resume context, semantic repetition detection, layered completion

## Next Ideas
- Compress SKILL.md prose (remove redundant sections, merge instructions)
- Flatten PRD JSON example (reduce boilerplate in skill instructions)
- Simplify flag documentation
- Consider merging cancel into main skill (save separate skill overhead)
- Remove verbose code block examples from SKILL.md
- Compress hook TypeScript (remove unnecessary type annotations)

---

## Experiment Log
