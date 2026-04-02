---
name: create-pr
description: Create PR — commit, push, PR, wait for merge.
---

Execute each line literally (scripts MUST be run, not reimplemented):

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
# If on main/master: checkout -b <type>/<short> first
"$S/preflight-check.sh"          # syncs if behind base
git add <files> && git commit -m "type(scope): msg"
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
gh pr merge --auto --squash
"$S/wait-for-merge.sh"           # 0=done 1=CI fail(prints run-id)
```

CI fail: `gh run view <run-id> --log-failed` → `me:pr-pass` → re-enable `gh pr merge --auto --squash` → re-run wait. Stop if unclear/×2.
PR body: fill PR template if exists, else summary+changes+tests.
