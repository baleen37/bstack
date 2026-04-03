# Autoresearch: Ralph Plugin Optimization

## Objective
Optimize the `plugins/ralph/` plugin for simplicity and token efficiency. SKILL.md files are loaded into LLM context when invoked — fewer bytes = less cost. The hook (ralph-persist.ts) runs at OS level but should also be minimal and clean.

## Metrics
- **Primary**: skill_bytes (bytes, lower is better) — ralph/SKILL.md byte count
- **Secondary**: skill_lines, cancel_bytes, hook_bytes, hook_lines, total_bytes

## How to Run
`./.autoresearch/run.sh` — outputs `METRIC name=number` lines. Validates frontmatter, hooks.json, TS compilation, and BATS tests.

## Files in Scope
| File | Purpose |
|------|---------|
| `plugins/ralph/skills/ralph/SKILL.md` | Main skill (LLM context — primary target) |
| `plugins/ralph/skills/ralph-cancel/SKILL.md` | Cancel skill (LLM context) |
| `plugins/ralph/hooks/ralph-persist.ts` | Stop hook engine (Bun runtime) |
| `plugins/ralph/hooks/hooks.json` | Hook registration config |

## Off Limits
- Do not break the persistence loop workflow (activate → iterate → complete)
- Cancel signal mechanism must work
- Session isolation must be preserved
- Stale state recovery must work
- Always exit 0 (never crash Claude)
- plugin.json metadata

## Constraints
- Tests must pass (ralph_persist.bats + ralph_hooks_json.bats)
- SKILL.md must have valid frontmatter
- hooks.json must be valid JSON
- TypeScript must compile with bun

## What's Been Tried
(Starting fresh — no experiments yet)
