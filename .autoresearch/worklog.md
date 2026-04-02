# Worklog: create-pr token efficiency

## Session Info
- Started: 2026-04-02
- Goal: Reduce token cost of create-pr skill while keeping it simple, correct, and effective

---

### Segment 0 (total_bytes): Runs 1-9
Compressed all files from 9073→2884 bytes (-68.2%):
- Removed verbose error messages/comments in scripts
- Removed unused verify-pr-status.sh
- Merged sync-with-base.sh into preflight-check.sh
- Inlined lib.sh (only used by 1 script)

### Segment 1 (skill_bytes): Runs 10-27
Re-focused on SKILL.md only (what LLM reads). 1081→776 bytes (-28.2%):
- Removed redundant sections, shortened description
- Extracted `S=` path variable
- Added "scripts MUST be run" directive (test-driven)
- Added auto-merge re-enable after CI fix (test-driven)
- Removed redundant "re-run preflight" instruction
- Fixed broken tests (63/63 pass)

### Subagent Tests (4 PRs)
| PR | Scenario | Finding |
|----|----------|---------|
| #604 | basic optimized flow | push -u needed, auto-merge disabled after push |
| #605 | main branch | agent skipped scripts → added MUST directive |
| #606 | MUST directive | scripts executed correctly, stale tests found |
| #607 | final validation | clean pass, 14 tool calls |

### Bug Fixes Found Through Testing
1. preflight push needs `-u` for new branches
2. auto-merge disabled after force-push → added re-enable instruction
3. agent skipping scripts → added "MUST be run" directive
4. stale tests referencing deleted scripts → updated test suite
5. `--delete-branch` in fallback merge inconsistent → removed

---

## Key Insights
- SKILL.md is the only file that costs tokens — scripts don't load into context
- "MUST run" directive is essential — without it agents reimplement script logic
- Real testing (subagent PRs) found 5 bugs that static analysis missed
- Byte reduction has diminishing returns below ~700 bytes for this skill
- Code block format is the primary instruction channel for LLM agents
