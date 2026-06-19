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
gh pr create --title "$(git log -1 --pretty=%s)" --body-file /tmp/pr_body.md
# Auto merge: only if user explicitly requests it
# gh pr merge --auto --squash
# REQUIRED: invoke via Monitor tool — streams per-check events + terminal event.
# Monitor({command: "\"$S/wait-for-merge.sh\"", description: "PR checks", timeout_ms: 1800000, persistent: false})
```

Write the PR body to a file and pass it with `--body-file`. Do not put setup commands or PR body text inside --title.

If user requests auto merge: `gh pr merge --auto --squash` → invoke `"$S/wait-for-merge.sh"` via the Monitor tool. Each `check: <name>: <bucket>` line streams as a notification; the terminal event has one of these prefixes — branch on it:
- `MERGED:` → done
- `AWAITING_REVIEW:` → CI green, needs reviewer
- `CI_FAILED: <url> run-id=<id>` → `gh run view <run-id> --log-failed` → `me:fix-pr` once → re-enable `gh pr merge --auto --squash` → re-invoke Monitor. Stop if unclear or still failing.
- `CLOSED:` → stop.
PR body: fill PR template if exists, else summary+changes+tests. Write /tmp/pr_body.md in ONE Write call (compose the full body first); never Write/Edit it twice — re-Read before any second write.
