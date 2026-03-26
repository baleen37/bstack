# Autoresearch: create-pr skill quality

## Objective
Improve the create-pr skill's overall quality: SKILL.md prompt clarity, shell script robustness, error handling, code deduplication, and test coverage. The workload is a composite quality score derived from static analysis, test results, and structural checks across the skill's SKILL.md and 4 shell scripts.

## Metrics
- **Primary**: quality_score (points, higher is better) — composite of shellcheck, tests, code quality, SKILL.md quality
- **Secondary**: shellcheck_warnings, test_pass_rate, code_quality, skillmd_quality

## How to Run
`./autoresearch.sh` — outputs `METRIC name=number` lines.

## Files in Scope
| File | Description |
|------|-------------|
| `SKILL.md` | Skill prompt — defines the PR workflow for the LLM |
| `scripts/preflight-check.sh` | Pre-push checks: BEHIND, conflicts, branch protection |
| `scripts/wait-for-merge.sh` | Blocks until CI completes and PR merges |
| `scripts/verify-pr-status.sh` | Read-only PR status verification |
| `scripts/sync-with-base.sh` | Syncs branch with base and pushes |
| `../../tests/skills/test_create_pr_verify_status.bats` | BATS test suite (relative: tests/skills/) |

## Off Limits
- Other skills and plugins
- Root-level config files (package.json, .releaserc.js, etc.)
- CI/CD configuration
- The autoresearch files themselves

## Constraints
- All existing BATS tests must continue to pass
- No new external dependencies
- ShellCheck must produce 0 warnings
- Scripts must keep `set -euo pipefail`
- Match existing code style in the project
- SKILL.md must remain a valid skill (YAML frontmatter + markdown)

## What's Been Tried

### Wins
1. **stderr routing** (+5pts): All error/failure messages (ERROR:, ✗, ⚠) now go to stderr across all scripts
2. **DRY base branch detection** (+5pts): Created `lib.sh` with `resolve_base_branch()`, replaced 3x duplicated detection logic in preflight-check, verify-pr-status, sync-with-base
3. **DRY git repo check** (+0pts score, structural improvement): Added `require_git_repo()` to lib.sh, replaced 2x duplicated checks
4. **SKILL.md Recovery section** (+1pt): Documented sync-with-base and verify-pr-status as recovery tools
5. **Test coverage** (+1pt, 23→33 tests): Added lib.sh tests (5), sync-with-base tests (5)

### Architecture Insights
- "ERROR:" prefix for environment/precondition failures (exit 2), "✗" for operation failures (exit 1) is a meaningful convention worth preserving
- ShellCheck requires `-x --source-path` when scripts source shared libraries
- lib.sh needs same documentation standards (usage, exit codes) as standalone scripts
