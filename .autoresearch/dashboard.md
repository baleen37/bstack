# Autoresearch Dashboard: create-pr-optimize

## Segment 1: skill_bytes (SKILL.md only)
**Runs:** 14 | **Kept:** 12 | **Discarded:** 1 | **Tests:** 1
**Baseline:** 1081 bytes (#10)
**Best pure:** 605 bytes (#15, -44.0%)
**Current:** 794 bytes (#19, -26.5%) — includes test-driven fixes

| # | commit | skill_bytes | status | description |
|---|--------|-------------|--------|-------------|
| 10 | 1b650ac | 1081 | keep | baseline |
| 11 | 6ba0c3d | 802 (-25.8%) | keep | remove redundant sections |
| 12 | ec416bc | 732 (-32.3%) | keep | extract S= path variable |
| 13 | 9bb6f1e | 675 (-37.6%) | keep | merge comments, remove bold |
| 14 | 563874d | 635 (-41.3%) | keep | micro-compress wording |
| 15 | 059de59 | 605 (-44.0%) | keep | remove template path |
| 16 | 059de59 | 608 | discard | merge create+merge lines |
| 17 | 96b1a8f | 665 | keep | add auto-merge re-enable (test fix) |
| 18 | - | - | test | edge: main branch — agent skipped scripts |
| 19 | b2e1f87 | 794 | keep | "scripts MUST be run" directive |
| 20 | - | - | test | edge: nothing-to-commit — agent handled correctly |
| 22 | - | - | test | must-run directive confirmed working |
| 23 | dece665 | 794 | keep | fix broken tests — 63/63 pass |

## Subagent Test Results
| PR | Scenario | Result | Finding |
|----|----------|--------|---------|
| #601-602 | basic flow (main SKILL) | pass | - |
| #604 | optimized SKILL | pass | auto-merge disabled after push, push -u needed |
| #605 | main branch edge | pass | agent skipped scripts (fixed with MUST directive) |
| #606 | MUST directive test | pass | scripts executed correctly, CI failed on stale tests |
