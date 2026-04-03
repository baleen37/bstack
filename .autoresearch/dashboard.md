# Autoresearch Dashboard: ralph-optimize

**Runs:** 20 | **Kept:** 17 | **Discarded:** 0 | **Crashed:** 0
**Baseline:** skill=2914, total=7357 bytes
**Final:** skill=1098 (-62.3%), total=3909 (-46.9%)
**Agent clarity:** 7/10

| # | skill | cancel | hook | total | description |
|---|-------|--------|------|-------|-------------|
| 1 | 2914 | 696 | 3747 | 7357 | baseline |
| 2 | 1710 | 696 | 3747 | 6153 | compress SKILL.md |
| 3 | 1364 | 696 | 3747 | 5807 | further compress |
| 5 | 1364 | 431 | 2725 | 4520 | simplify hook |
| 7 | 1260 | 431 | 2157 | 3848 | compress hook |
| 11 | 1193 | 431 | 1962 | 3586 | best pure compression |
| 15 | 1359 | 431 | 1962 | 3752 | +clarity (agent fixes) |
| 19 | 1438 | 525 | 2286 | 4249 | +story progress in hook |
| 20 | 1098 | 525 | 2286 | 3909 | final: simplified for universal use |

## Agent Tests (7 total, all pass)
| Scenario | Clarity Finding |
|----------|----------------|
| Simple task | progress.txt init, deslop vague |
| Multi-story | one-at-a-time unclear |
| --no-prd | "skip PRD" contradictory |
| Edge cases | retry flow works |
| ralph-cancel | CWD + hook explanation needed |
| Calculator | 7/10 — clean |
| Calculator --no-prd | 7/10 — auto-generate rule wanted |
