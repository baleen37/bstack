# Autoresearch Dashboard: create-pr-quality

**Runs:** 6 | **Kept:** 6 | **Discarded:** 0 | **Crashed:** 0
**Baseline:** quality_score: 93 points (#3, segment 1)
**Best:** quality_score: 100 points (#5, +7.5%)

| # | commit | quality_score | shellcheck | tests | code_quality | skillmd | advanced | status | description |
|---|--------|---------------|------------|-------|--------------|---------|----------|--------|-------------|
| 1 | 46e5b1f | 90 | 0 | 100% | 15 | 25 | — | keep | baseline (segment 0) |
| 2 | f6cbdb0 | 95 (+5.6%) | 0 | 100% | 20 | 25 | — | keep | send all error/failure messages to stderr |
| 3 | d5d28b4 | 93 | 0 | 100% | 20 | 19 | 14 | keep | expanded metrics (segment 1 baseline) |
| 4 | 800f539 | 98 (+5.4%) | 0 | 100% | 20 | 19 | 19 | keep | extract shared base branch detection to lib.sh |
| 5 | 1ad9e76 | 100 (+7.5%) | 0 | 100% | 20 | 20 | 20 | keep | add recovery section, strengthen tests |
| 6 | f37228b | 100 (+0.0%) | 0 | 100% | 20 | 20 | 20 | keep | extract require_git_repo, add lib.sh tests |
