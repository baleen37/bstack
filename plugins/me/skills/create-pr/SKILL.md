---
name: create-pr
description: Use when the user asks to "create a PR", "create pull request", "open a PR", "submit a PR", "make a pull request", "merge PR", or requests complete git workflow including commit, push, and PR creation
---

# Create PR

Full PR flow: pre-flight → commit → push → PR → wait-for-merge.

## Workflow

```bash
# 1) pre-flight (parallel: git status, git branch --show-current, git log --oneline -5)
# If on main/master: git checkout -b <type>/<short-description> (from last commit subject)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/preflight-check.sh"
# If BEHIND: "${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/sync-with-base.sh"

# 2) commit
git add <specific-files>
git commit -m "type(scope): summary"

# 3) push + PR + auto-merge
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
gh pr merge --auto --squash

# 4) wait
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/wait-for-merge.sh"
# exit 0: done (merged or awaiting review)
# exit 1: CI failed → diagnose then invoke me:pr-pass
```

## CI Failure

`wait-for-merge.sh` prints the failed `run-id`. Use it directly:
```bash
gh run view <run-id> --log-failed 2>&1 | grep -A3 "not ok\|Error\|FAILED" | head -40
```

Invoke `me:pr-pass`. After fix is pushed, re-run `wait-for-merge.sh`.

**Stop (ask user) if:**
- Root cause ambiguous after reading logs
- Fix requires architecture decisions
- `me:pr-pass` invoked twice with no progress

## Stop Conditions

- Nothing to commit and no unpushed commits
- Sync failed (conflicts need manual resolution)
- `me:pr-pass` cannot determine a clear fix

## PR Body

**If template found** (`.github/PULL_REQUEST_TEMPLATE.md` → `PULL_REQUEST_TEMPLATE.md`): fill each section, preserve `- [ ]` as-is.

**No template:** Summary (1-2 sentences) + Changes (bullets) + Tests
