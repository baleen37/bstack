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

The wrapper handles preflight, base-branch sync, selected-file staging, commit, push, existing PR detection,
PR creation, optional auto-merge, and merge waiting. It passes the PR body with `--body-file` using a
per-run file; do not create shared temporary PR body files.

Preflight outcomes:

- `OK`: continue.
- `NOOP:` or `MERGED:`: terminal; stop.
- `Behind base — syncing...`: base was merged into this branch and pushed; continue only after the wrapper
  finishes successfully.
- exit `1`: blocking. Run `git status --short`. Resolve `UU` conflicts or abort the merge; if no `UU`
  files, commit/stash local changes and rerun.
- exit `2`: environment error. Fix repo/origin/base branch discovery; do not create a PR.

Branch only on terminal prefixes:

- `NOOP:` → nothing to PR
- `PR_EXISTS:` → PR already exists; continue to auto-merge/wait only if requested
- `MERGED:` → done
- `AWAITING_REVIEW:` → CI green, needs reviewer
- `CI_FAILED: <url> run-id=<id>` → `gh run view <id> --log-failed`, then use `me:fix-pr` once.
  If id is `unknown`, inspect `gh pr checks --json name,bucket,link` first. Stop if unclear or still failing.
- `CLOSED:` → stop.

PR body: fill PR template if exists, else summary+changes+tests. Pipe it once to the wrapper; do not put
setup commands or PR body text inside the commit title.
