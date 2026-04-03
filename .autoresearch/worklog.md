# Worklog: Ralph Plugin Optimization

## Session Info
- **Goal:** Optimize Ralph plugin for simplicity, token efficiency, and clarity
- **Branch:** autoresearch/ralph-improve-20260403
- **Started:** 2026-04-03
- **Primary Metric:** skill_bytes (SKILL.md byte count, lower is better)

## Summary
- Baseline: skill=2914, cancel=696, hook=3747, total=7357 bytes
- Current: skill=1396, cancel=525, hook=1962, total=3883 bytes
- Net reduction: **-47.2% total bytes** (-52.1% skill, -24.6% cancel, -47.6% hook)

## Phase 1: Byte Compression (runs 1-11)
- Flattened JSON examples, removed redundant sections
- Simplified TypeScript hook (removed interfaces, extracted helpers)
- Shortened variable names, block messages
- Merged sections (Verification + Done)
- Extracted $S path variable
- Best: skill=1193 bytes (-59.1%), total=3586 (-51.3%)

## Phase 2: Agent Testing + Clarity (runs 13-17)
Ran 5 subagent tests with real tasks. Found and fixed:
1. progress.txt init unclear → added "skip on first iteration"
2. --no-prd completely undefined → added "auto-generate prd.json with task as single story"
3. Deslop too vague → enumerated what to remove
4. TDD with existing tests → clarified "write failing test (or use existing tests)"
5. ralph-cancel missing CWD context → added
6. cancel-signal purpose unexplained → added hook explanation

Bytes increased from 3586 → 3883 (+297 bytes) but all agent tests now pass cleanly.

## Key Insights
- Byte compression alone is misleading — agents misinterpret unclear instructions, costing more overall
- Agent testing (not just BATS unit tests) catches real usability issues
- --no-prd was completely broken in practice despite passing all unit tests
- "skip PRD" + "create prd.json" is contradictory — changed to "skip elaboration"
- progress.txt timing matters: TDD initial failure ≠ implementation failure

## Next Ideas
- Test multi-iteration failure scenario (progress.txt accumulation)
- Test resume after crash (partial state)
- Consider adding iteration context to block message (e.g., current story)
- Test with larger real-world tasks
- Hook improvement: track which story is in progress
