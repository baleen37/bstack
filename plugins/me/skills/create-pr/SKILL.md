---
name: create-pr
description: Create PR — commit, push, PR, wait for merge.
---

Run these lines as written. The scripts carry the tested sync and merge-wait logic; do not reimplement them:

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
# If on main/master: checkout -b <type>/<short> first
git add <files> && git commit -m "type(scope): msg"
"$S/preflight-check.sh"          # after the commit: syncs if behind base (needs a clean tree)
git push -u origin HEAD
gh pr create --title "$(git log -1 --pretty=%s)" --body "<body>"
# Auto merge: only if user explicitly requests it
# gh pr merge --auto --squash
# Watch checks via the Monitor tool so per-check events and the terminal event stream as notifications.
# Monitor({command: "\"$S/wait-for-merge.sh\"", description: "PR checks", timeout_ms: 1800000, persistent: false})
```

`wait-for-merge.sh` only observes; it never merges. Merging happens only through
`gh pr merge --auto --squash`, and only when the user asked for it. Each `check: <name>: <bucket>`
line streams as a notification; the terminal event has one of these prefixes — branch on it:

- `MERGED:` → done
- `AWAITING_REVIEW:` → CI green, not merged (no auto merge enabled, or a reviewer is required)
- `CI_FAILED: <url> run-id=<id>` → `gh run view <run-id> --log-failed` → fix the failure once →
  commit, push → re-enable `gh pr merge --auto --squash` if it was requested → re-invoke Monitor.
  Stop if unclear or still failing.
- `CLOSED:` → stop.

PR body: fill PR template if exists, else summary+changes+tests.
