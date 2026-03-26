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
(Nothing yet — baseline run pending)
