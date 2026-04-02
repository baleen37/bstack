---
name: create-pr
description: Create PR — commit, push, PR, wait for merge.
---

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
"$S/preflight-check.sh"   # syncs if behind; on main→checkout -b type/desc
git add <files> && git commit -m "type(scope): msg"
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
gh pr merge --auto --squash
"$S/wait-for-merge.sh"    # 0=done 1=CI fail(prints run-id)
```

CI fail: `gh run view <run-id> --log-failed` → `me:pr-pass`. Stop if unclear/tried ×2.

PR body: fill `.github/PULL_REQUEST_TEMPLATE.md` if exists, else summary+changes+tests.
