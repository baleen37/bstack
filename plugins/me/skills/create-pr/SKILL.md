---
name: create-pr
description: Use when committing changes, creating or reusing a PR, enabling auto-merge, or confirming merge status
---

Run the wrapper; never reimplement git/gh checks or body files.

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
# If on main/master, create a topic branch first.
printf '%s\n' "<full PR body>" | "$S/create-pr.sh" "type(scope): msg" -- <files>
printf '%s\n' "<full PR body>" | "$S/create-pr.sh" --auto-merge "type(scope): msg" -- <files>
```

Body: template if present, else Summary/Changes/Tests. Pipe once. Stage only requested
files. Keep setup/body text out of the commit title.

The wrapper owns preflight, sync, staging, commit, push, PR create/reuse, auto-merge.

**stdout is the contract.** It prints exactly ONE terminal line to stdout; act on it and
ignore stderr (git logs, a `READY:` preview). It is authoritative — don't re-run
`gh pr view`/`git status`.

| stdout line | Action |
| ----------- | ------ |
| `NOOP:` | Stop; nothing to PR. |
| `PR_EXISTS: <url>` | PR open (created or reused); auto-merge only if asked. |
| `MERGED:` | Done. |
| `AWAITING_REVIEW:` | CI green, needs a reviewer; stop. |
| `CI_FAILED: <url> run-id=<id>` | Inspect logs, then `me:fix-pr` once. |
| `CLOSED:` | Stop. |

Failures (nonzero exit, empty stdout — read stderr):

- `CONFLICT:` then filenames: resolve them, re-run.
- `Push failed` / `PR create failed; no existing PR found.`: publish failed (commit kept).
  Don't re-run/hand-roll; check `gh auth status`, report, resume once fixed.
- exit `2`: fix repo/origin/base discovery; don't create a PR.
- `ERROR: No PR` after auto-merge may be a fast-merge race; verify with `gh pr view`.
