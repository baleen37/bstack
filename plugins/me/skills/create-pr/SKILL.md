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
gh pr merge --auto --squash    # default: squash merge, do not ask
# REQUIRED: invoke via Monitor tool — streams per-check events + terminal event.
# Monitor({command: "\"$S/wait-for-merge.sh\"", description: "PR checks", timeout_ms: 1800000, persistent: false})
```

Merge policy: always squash, always `--auto`, never prompt the user. If the user explicitly asks for
a different merge strategy (e.g. merge commit, rebase), honor that instead. Then invoke
`"$S/wait-for-merge.sh"` via the Monitor tool. Each `check: <name>: <bucket>` line streams as a
notification; the terminal event has one of these prefixes — branch on it:

- `MERGED:` → done
- `AWAITING_REVIEW:` → CI green, needs reviewer
- `CI_FAILED: <url> run-id=<id>` → `gh run view <run-id> --log-failed` → `me:fix-pr` once →
  re-enable `gh pr merge --auto --squash` → re-invoke Monitor. Stop if unclear or still failing.
- `CLOSED:` → stop.
PR body: fill PR template if exists, else summary+changes+tests.
