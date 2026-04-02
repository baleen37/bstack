---
name: create-pr
description: Use when user asks to create a PR, open a pull request, push and merge, or complete a git commit/push/PR workflow.
---

# Create PR

Pre-flight → commit → push → PR → wait-for-merge.

## Workflow

```bash
# 1) pre-flight (checks behind + auto-syncs if needed)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/preflight-check.sh"
# If on main/master: git checkout -b <type>/<short-description>

# 2) commit
git add <specific-files>
git commit -m "type(scope): summary"

# 3) push + PR + auto-merge
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
gh pr merge --auto --squash

# 4) wait
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/wait-for-merge.sh"
# exit 0: done | exit 1: CI failed → read logs, invoke me:pr-pass
```

## CI Failure

`wait-for-merge.sh` prints `run-id`. Read logs:
```bash
gh run view <run-id> --log-failed 2>&1 | grep -A3 "not ok\|Error\|FAILED" | head -40
```
Invoke `me:pr-pass`. Re-run `wait-for-merge.sh` after fix.

**Stop if:** root cause unclear, architecture decision needed, or `me:pr-pass` invoked twice without progress.

## Stop Conditions

- Nothing to commit and no unpushed commits
- Preflight failed with conflicts (manual resolution needed)

## PR Body

**Template found** (`.github/PULL_REQUEST_TEMPLATE.md`): fill sections, keep `- [ ]` as-is.
**No template:** Summary (1-2 sentences) + Changes (bullets) + Tests.
