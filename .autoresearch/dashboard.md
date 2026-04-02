# Autoresearch Dashboard: create-pr-optimize

## Segment 0: total_bytes (all files)
**Runs:** 9 | **Kept:** 9 | Baseline: 9073 → Best: 2884 (-68.2%)

## Segment 1: skill_bytes (SKILL.md only)
**Runs:** 8 | **Kept:** 7 | **Discarded:** 1
**Baseline:** 1081 bytes (#10)
**Best:** 605 bytes (#15, -44.0%)
**Current:** 665 bytes (#17, -38.5%) — includes critical auto-merge fix

| # | commit | skill_bytes | status | description |
|---|--------|-------------|--------|-------------|
| 10 | 1b650ac | 1081 | keep | baseline (segment 1) |
| 11 | 6ba0c3d | 802 (-25.8%) | keep | remove redundant sections |
| 12 | ec416bc | 732 (-32.3%) | keep | extract script path variable |
| 13 | 9bb6f1e | 675 (-37.6%) | keep | merge comments, remove bold |
| 14 | 563874d | 635 (-41.3%) | keep | micro-compress wording |
| 15 | 059de59 | 605 (-44.0%) | keep | remove template path |
| 16 | 059de59 | 608 (-43.8%) | discard | merge create+merge (bytes increased) |
| 17 | 96b1a8f | 665 (-38.5%) | keep | add auto-merge re-enable (bug fix from test) |
