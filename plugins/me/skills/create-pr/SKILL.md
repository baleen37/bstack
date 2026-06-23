---
name: create-pr
description: Create PR — commit, push, PR, wait for merge.
---

Execute this block literally (scripts MUST be run, not reimplemented; keep multi-line commands together):

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
BASE="${BASE:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)}"
# If on main/master: checkout -b <type>/<short> first
"$S/preflight-check.sh" "$BASE"  # syncs if behind base
git add <files>
if git diff --cached --quiet; then
  if gh pr view --json url --jq .url >/dev/null 2>&1; then
    echo "PR already exists: $(gh pr view --json url --jq .url)"
  elif git diff --quiet "origin/$BASE"...HEAD; then
    echo "No staged changes or branch diff; nothing to PR."
    exit 0
  fi
else
  git commit -m "type(scope): msg"
fi
git push -u origin HEAD
if gh pr view --json url --jq .url >/dev/null 2>&1; then
  echo "PR already exists: $(gh pr view --json url --jq .url)"
else
  if ! gh pr create --title "$(git log -1 --pretty=%s)" --body-file <(cat <<'PR_BODY'
<full PR body>
PR_BODY
  ); then
    gh pr view --json url --jq .url || { echo "PR create failed; no existing PR found."; exit 1; }
  fi
fi
# Auto merge: only if user explicitly requests it
# gh pr merge --auto --squash
# Prefer Monitor for streamed check events; if unavailable run "$S/wait-for-merge.sh" directly.
# Monitor({command: "\"$S/wait-for-merge.sh\"", description: "PR checks", timeout_ms: 1800000, persistent: false})
```

Preflight outcomes:

- `0`: ready. If output includes `Behind base — syncing...`, base was merged into this branch and pushed;
  continue only after `git status --short` is clean except intended changes.
- `1`: blocking. Run `git status --short`. Resolve `UU` conflicts or abort the merge; if no `UU` files,
  commit/stash local changes and rerun.
- `2`: environment error. Fix repo/origin/base branch discovery, or pass `BASE`; do not create a PR.

Pass the PR body with `--body-file` using the inline bash process substitution above. Do not put setup
commands or PR body text inside --title.

If user requests auto merge: `gh pr merge --auto --squash` → invoke `"$S/wait-for-merge.sh"` via Monitor.
If Monitor is unavailable, run the script directly. Branch on the terminal event prefix:

- `MERGED:` → done
- `AWAITING_REVIEW:` → CI green, needs reviewer
- `CI_FAILED: <url> run-id=<id>` → `gh run view <id> --log-failed`, then use `me:fix-pr` once.
  If id is `unknown`, inspect `gh pr checks --json name,bucket,link` first. Stop if unclear or still failing.
- `CLOSED:` → stop.

PR body: fill PR template if exists, else summary+changes+tests. Replace `<full PR body>` with the
complete body; do not create shared temporary PR body files.
