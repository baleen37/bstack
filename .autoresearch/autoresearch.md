# Autoresearch: create-pr token efficiency

## Objective
Optimize the `plugins/me/skills/create-pr/` skill for token efficiency and correctness. SKILL.md is loaded into LLM context when invoked — fewer bytes = less cost. Scripts run at execution time and don't affect token cost, but must be correct.

## Metrics
- **Primary**: skill_bytes (bytes, lower is better) — SKILL.md byte count
- **Secondary**: skill_lines, skill_words, script_bytes

## How to Run
`./.autoresearch/run.sh` — outputs `METRIC name=number` lines.

## Files in Scope
| File | Purpose |
|------|---------|
| `plugins/me/skills/create-pr/SKILL.md` | Main skill definition (loaded into LLM context) |
| `plugins/me/skills/create-pr/scripts/preflight-check.sh` | Pre-push checks + auto-sync |
| `plugins/me/skills/create-pr/scripts/wait-for-merge.sh` | Wait for CI + merge |

## Off Limits
- Do not break the PR workflow
- Exit codes must be preserved

## Constraints
- Scripts must pass shellcheck
- SKILL.md must have valid frontmatter
- Tests must pass (63/63)

## What's Been Tried
### Structural changes (big wins)
- Removed unused verify-pr-status.sh (-1302 bytes)
- Merged sync-with-base.sh into preflight-check.sh (-515 bytes)
- Inlined lib.sh into preflight-check.sh (-461 bytes)

### SKILL.md compression (medium wins)
- Removed Overview, When to Use, Stop Conditions sections
- Extracted S= path variable for script paths
- Removed bold markdown markers, flattened sections

### Test-driven fixes (increased bytes for correctness)
- "scripts MUST be run" directive (+129 bytes) — agents were skipping scripts
- auto-merge re-enable after CI fix (+60 bytes) — tested on PR #604
- push -u in preflight — new branches had no upstream

### Dead ends
- Merging gh pr create + merge into one line — bytes increased
- Further compression below ~700 bytes — losing essential information
