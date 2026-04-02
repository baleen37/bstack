# Autoresearch: create-pr token efficiency

## Objective
Optimize the `plugins/me/skills/create-pr/` skill for token efficiency. The skill is loaded into LLM context when invoked, so fewer bytes = less cost per invocation. Must remain functionally correct, simple, and problem-free. The skill guides Claude Code through: preflight checks → commit → push → PR creation → wait for merge/CI.

## Metrics
- **Primary**: total_bytes (bytes, lower is better) — total bytes of SKILL.md + all scripts
- **Secondary**: line_count (lines), file_count (files), word_count (words)

## How to Run
`./.autoresearch/run.sh` — outputs `METRIC name=number` lines.

## Files in Scope
| File | Purpose |
|------|---------|
| `plugins/me/skills/create-pr/SKILL.md` | Main skill definition loaded into LLM context |
| `plugins/me/skills/create-pr/scripts/lib.sh` | Shared utils (require_git_repo, resolve_base_branch) |
| `plugins/me/skills/create-pr/scripts/preflight-check.sh` | Pre-push checks: behind, conflicts |
| `plugins/me/skills/create-pr/scripts/sync-with-base.sh` | Sync branch with base |
| `plugins/me/skills/create-pr/scripts/verify-pr-status.sh` | Check PR merge status |
| `plugins/me/skills/create-pr/scripts/wait-for-merge.sh` | Wait for CI + merge |

## Off Limits
- Do not break the PR workflow (commit → push → PR → merge)
- Do not remove essential error handling (exit codes must be preserved)
- Do not change the script interface (arguments, exit codes)

## Constraints
- Scripts must pass shellcheck
- SKILL.md must remain a valid skill file (frontmatter + instructions)
- All exit codes must be preserved (0=success, 1=blocking, 2=env error)
- `gh` CLI and `jq` dependencies are fine
- Token reduction must not sacrifice clarity of instructions to the LLM

## What's Been Tried
(Updated as experiments accumulate)
