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

### Segment 1 (skill_bytes): Runs 10-17
Re-focused on SKILL.md only (what LLM actually reads). 1081→665 bytes (-38.5%):
- Removed redundant sections (Overview, When to Use, Stop Conditions)
- Extracted `S=` variable for script path (saves 40+ chars)
- Flattened code block comments
- Removed bold markdown markers
- **Run 17 (test-driven fix):** Added auto-merge re-enable after CI fix push

### Subagent Tests
- **Test 1 (PR #601-602):** tmux worker on main branch, used old SKILL.md. Succeeded but used old sync-with-base.sh.
- **Test 2 (PR #604):** subagent on optimized branch. Succeeded but found:
  - preflight push needs `-u` for new branches (fixed)
  - auto-merge disabled after fix push (added to SKILL.md)

---

## Key Insights
- Scripts don't load into LLM context — only SKILL.md bytes matter for token cost
- Byte reduction has diminishing returns below ~600 bytes
- Real testing (subagent PRs) found bugs that byte counting never would
- LLM follows the code block as primary instruction; prose sections are secondary
- `S=` path variable is the single biggest SKILL.md byte saver

## Next Ideas
- Test with a project that has PR template to verify template detection
- Consider if `gh pr merge --auto --squash` should be in wait-for-merge.sh instead
- Verify preflight works correctly on repos without gh CLI auth
