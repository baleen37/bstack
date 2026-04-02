---
name: create-pr
description: Use when user asks to create a PR, open a pull request, push and merge, or complete a git commit/push/PR workflow.
---

# Create PR

```bash
# 1) pre-flight (auto-syncs if behind base)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/preflight-check.sh"
# On main/master? → git checkout -b <type>/<short-description>

# 2) commit + push + PR
git add <files> && git commit -m "type(scope): summary"
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
gh pr merge --auto --squash

# 3) wait (exit 0=done, exit 1=CI failed)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/wait-for-merge.sh"
```

**CI failure:** `wait-for-merge.sh` prints `run-id` → `gh run view <run-id> --log-failed 2>&1 | head -40` → invoke `me:pr-pass` → re-run wait. Stop if root cause unclear or `me:pr-pass` tried twice.

**Stop:** nothing to commit, no unpushed commits, or conflicts need manual resolution.

**PR body:** Use `.github/PULL_REQUEST_TEMPLATE.md` if exists (keep `- [ ]`). Otherwise: summary + change bullets + tests.
