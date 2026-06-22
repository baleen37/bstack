---
name: create-pr
description: Create PR — commit, push, PR, wait for merge.
---

Run the wrapper. Do not reimplement its git/gh checks.

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
# If on main/master: checkout -b <type>/<short> first
printf '%s\n' "<full PR body>" | "$S/create-pr.sh" "type(scope): msg" -- <files>
# If auto merge was requested:
printf '%s\n' "<full PR body>" | "$S/create-pr.sh" --auto-merge "type(scope): msg" -- <files>
```

The wrapper handles preflight, safe `/tmp/pr_body.md` creation, commit, push, PR creation, optional auto-merge, and
merge waiting.

Branch only on terminal prefixes:

- `NOOP:` → nothing to PR
- `MERGED:` → done
- `AWAITING_REVIEW:` → CI green, needs reviewer
- `CI_FAILED: <url> run-id=<id>` → inspect failed log, use `me:fix-pr` once, then retry auto-merge
- `CLOSED:` → stop.

PR body: fill PR template if exists, else summary+changes+tests. Pipe it once to the wrapper; never Write/Edit
`/tmp/pr_body.md`.
