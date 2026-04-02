---
name: create-pr
description: Create a PR — commit, push, open PR, wait for merge.
---

```bash
# 1) pre-flight (auto-syncs if behind)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/preflight-check.sh"
# On main/master? → git checkout -b <type>/<short>

# 2) commit + push + PR
git add <files> && git commit -m "type(scope): summary"
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
gh pr merge --auto --squash

# 3) wait (exit 0=done, exit 1=CI failed)
"${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts/wait-for-merge.sh"
```

**CI fail:** wait prints `run-id` → `gh run view <run-id> --log-failed` → invoke `me:pr-pass`. Stop if unclear or tried twice.

**PR body:** Fill `.github/PULL_REQUEST_TEMPLATE.md` if exists, else summary + changes + tests.
