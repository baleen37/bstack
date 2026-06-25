---
name: create-pr
description: Use when committing changes, creating or reusing a PR, enabling auto-merge, or confirming merge status
---

Run the wrapper; never reimplement git/gh checks or body temp files.

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
# If on main/master, create a topic branch first.
printf '%s\n' "<full PR body>" | "$S/create-pr.sh" "type(scope): msg" -- <files>
printf '%s\n' "<full PR body>" | "$S/create-pr.sh" --auto-merge "type(scope): msg" -- <files>
```

Body: template if present, else Summary/Changes/Tests. Pipe once. Stage only requested files.
Keep setup/body text out of the commit title.

The wrapper owns preflight, sync, staging, commit, push, PR create/reuse, auto-merge, wait.

Act only on terminal prefixes:

| Output | Action |
| ------ | ------ |
| `NOOP:` | Stop; nothing to PR. |
| `PR_EXISTS:` | Reuse it; auto-merge/wait only if requested. |
| `MERGED:` | Done. |
| `AWAITING_REVIEW:` | CI green, reviewer needed; stop. |
| `CI_FAILED: <url> run-id=<id>` | Inspect logs, then use `me:fix-pr` once. |
| `CLOSED:` | Stop. |

Other outcomes:

- `Behind base - syncing...`: wait for the wrapper's final prefix.
- exit `1`: run `git status --short`; resolve `UU`, abort merge, or commit/stash dirt.
- exit `2`: fix repo/origin/base discovery; do not create a PR.
- `ERROR: No PR` after auto-merge can be a fast-merge race. Verify with `gh pr view` and fetch main.
