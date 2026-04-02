---
name: create-pr
description: Create a PR — commit, push, open PR, wait for merge.
---

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
"$S/preflight-check.sh"          # auto-syncs if behind base
# On main/master? → git checkout -b <type>/<short>
git add <files> && git commit -m "type(scope): summary"
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
gh pr merge --auto --squash
"$S/wait-for-merge.sh"           # exit 0=done, 1=CI failed
```

**CI fail:** wait prints `run-id` → `gh run view <run-id> --log-failed` → invoke `me:pr-pass`. Stop if unclear or tried twice.

**PR body:** Fill `.github/PULL_REQUEST_TEMPLATE.md` if exists, else summary + changes + tests.
