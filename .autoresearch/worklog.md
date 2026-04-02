# Worklog: create-pr token efficiency

## Session Info
- Started: 2026-04-02
- Goal: Reduce token cost of create-pr skill while keeping it simple, correct, and effective
- Files: SKILL.md + 5 shell scripts in plugins/me/skills/create-pr/

---

### Run 1: baseline — total_bytes=9073 (KEEP)
- Timestamp: 2026-04-02
- What changed: Nothing — initial measurement
- Result: 9073 bytes, 284 lines, 6 files, 1375 words
- Insight: Starting point. SKILL.md is 64 lines, scripts total 220 lines. lib.sh (32 lines) has 2 funcs used by 3 scripts.
- Next: Try trimming verbose error messages and comments in scripts

---

## Key Insights
- lib.sh is small but sourced by 3 scripts — keeping it avoids duplication
- verify-pr-status.sh seems unused by SKILL.md workflow (only wait-for-merge.sh is referenced)
- SKILL.md has good density already but could be tighter

## Next Ideas
- Remove verify-pr-status.sh if unused in the workflow
- Trim verbose error messages (multi-line hints) in scripts
- Compress SKILL.md prose
- Consolidate preflight + sync into one script
- Remove redundant comments/headers
