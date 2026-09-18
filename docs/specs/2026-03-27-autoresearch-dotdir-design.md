# Autoresearch: Consolidate outputs into `.autoresearch/`

## Problem

The autoresearch plugin scatters 7+ files across the project root during experiment sessions (`autoresearch.md`, `autoresearch.jsonl`, `autoresearch-dashboard.md`, `autoresearch.sh`, `autoresearch.ideas.md`, `.autoresearch-off`, `experiments/worklog.md`). This clutters the working directory.

## Solution

Move all autoresearch outputs into a single `.autoresearch/` directory. Drop redundant prefixes since the directory provides namespace.

## File Mapping

| Current | New | Notes |
|---------|-----|-------|
| `autoresearch.md` | `.autoresearch/autoresearch.md` | Session config, kept as-is |
| `autoresearch.jsonl` | `.autoresearch/autoresearch.jsonl` | State file, kept as-is |
| `autoresearch-dashboard.md` | `.autoresearch/dashboard.md` | Drop prefix |
| `autoresearch.ideas.md` | `.autoresearch/ideas.md` | Drop prefix |
| `autoresearch.sh` | `.autoresearch/run.sh` | Simplified name |
| `.autoresearch-off` | `.autoresearch/off` | Sentinel file |
| `experiments/worklog.md` | `.autoresearch/worklog.md` | Flatten directory |

## Active State Detection

- **Active session**: `.autoresearch/autoresearch.md` exists AND `.autoresearch/off` does not exist
- **Paused**: `.autoresearch/off` exists
- **Session complete**: Directory remains with `off` sentinel

## Files to Modify

1. `plugins/autoresearch/hooks/autoresearch-context.sh` — Update path checks
2. `plugins/autoresearch/commands/autoresearch.md` — Update all file paths
3. `plugins/autoresearch/skills/autoresearch/SKILL.md` — Update all file paths, add `mkdir -p .autoresearch`

## Not Changing

- Plugin structure (`plugins/autoresearch/` itself)
- JSONL protocol or experiment loop logic
- `.claude-plugin/` configuration
