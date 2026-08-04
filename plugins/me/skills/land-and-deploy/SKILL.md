---
name: land-and-deploy
description: Merge the PR, wait for deploy, verify production health, and revert if anything looks wrong. Picks up after /ship. (based on gstack)
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
  - Skill
---

# /land-and-deploy: Merge, deploy, verify

Based on https://github.com/garrytan/gstack `land-and-deploy/SKILL.md`. The workflow,
boundary (start at merge, not before), escape-hatch (revert), idempotent re-entry,
and non-blocking philosophy are all from gstack. Adapted for our repo's conventions:
delegate PR/merge work to `/create-pr`, let `semantic-release` handle versioning, and
infer the deploy method from each repo's own configuration.

## Boundary

This skill starts at **merge** and ends at **verified production health (or revert)**.

- It does NOT create PRs, run reviews, bump versions, or update changelogs. `/ship`
  owns release-readiness review; `/create-pr` owns commit/push/PR-create. If the PR
  doesn't exist yet, stop and tell the user to run `/ship` then `/create-pr`.
- It DOES merge, monitor CI/deploy, run a canary against the live site, and offer
  `git revert` if anything looks wrong.

## Idempotent re-entry

On entry, create a task list of the stages below with `TaskCreate`. Mark stages
`in_progress` / `completed` as you go. On re-entry (same branch, same PR), call
`TaskList` first and skip any stage already `completed` for this PR. Stages:

1. Pre-flight (PR detection + auth)
2. Pre-merge gate (CI green + no conflicts)
3. Merge (delegate to `/create-pr` with auto-merge)
4. Wait for deploy (CI workflow / platform-native / none)
5. Canary verification (live site health)
6. Deploy report
7. Revert (only if user opts in at any failure)

Drive these stages automatically. Do NOT ask the user to confirm between stages.
Stop only at the gates explicitly listed below (CI failing, merge conflict, deploy
failure, unhealthy canary, permission denied).

## Step 1: Pre-flight

```bash
gh auth status || { echo "Run 'gh auth login' first"; exit 1; }
gh pr view --json number,state,title,url,mergeStateStatus,mergeable,baseRefName,headRefName
```

- No PR on this branch → STOP: "No PR found. Run `/ship` then `/create-pr` first."
- `state=MERGED` → skip to Step 4 (deploy may still be in flight) and treat merge stage as already done.
- `state=CLOSED` → STOP.
- `state=OPEN` → continue.

Detect base branch via `gh pr view -q .baseRefName`, falling back to `main`.

## Step 2: Pre-merge gate

```bash
gh pr checks --json name,state,status,conclusion
gh pr view --json mergeable -q .mergeable
```

- Any required check `FAILED` → STOP, list failures, suggest `/pr-pass`.
- `mergeable=CONFLICTING` → STOP, suggest `/pr-pass`.
- Any check `PENDING` → wait via `gh pr checks --watch --fail-fast` (timeout 15 min).
  On timeout, STOP and ask the user to investigate.
- All green → continue.

Note: `/ship` already evaluated schema/data safety. Do NOT re-run readiness review here.

## Step 3: Merge (delegated)

Delegate to `/create-pr` with explicit auto-merge. Do not invent merge logic here:

```bash
S="${CLAUDE_PLUGIN_ROOT}/skills/create-pr/scripts"
gh pr merge --auto --squash --delete-branch \
  || gh pr merge --squash --delete-branch
"$S/wait-for-merge.sh"   # run_in_background:true; 0=merged, 1=CI fail
```

If `wait-for-merge.sh` exits non-zero with a CI failure, run `gh run view <run-id>
--log-failed`, invoke `Skill: me:pr-pass` to repair, then re-enable auto-merge.
Permission denied on merge → STOP, ask the user (branch protection / maintainer
required).

Capture the merge-commit SHA — it's needed for revert and deploy correlation:

```bash
MERGE_SHA=$(gh pr view --json mergeCommit -q .mergeCommit.oid)
BASE=$(gh pr view --json baseRefName -q .baseRefName)
```

After merge, our `semantic-release` runs automatically on the base branch.
Do NOT add a manual release/tag/publish step here.

## Step 4: Wait for deploy

Read each repo's own conventions to decide HOW to wait. The skill is generic; the
repo tells you what platform it uses. Check in this order:

1. **`CLAUDE.md` / `AGENTS.md`** — look for a "Deploy" section with platform name,
   production URL, and (optionally) status/health-check commands.
2. **GitHub Actions workflows** — `find .github/workflows -maxdepth 1 \( -name '*.yml' -o -name '*.yaml' \)`
   then grep for `deploy|release|production|cd`. If found, that's a CI-driven deploy.
3. **Platform config files** — `fly.toml` (Fly.io), `vercel.json`/`.vercel/` (Vercel),
   `render.yaml` (Render), `netlify.toml` (Netlify), `Procfile` (Heroku),
   `railway.json`/`railway.toml` (Railway).
4. **Diff scope** — if only docs changed (`git diff --name-only $BASE...HEAD` shows
   only `*.md`/`docs/**`), there is nothing to deploy. Skip to Step 6.

Then wait per detected strategy:

- **GitHub Actions deploy workflow:** find the run for `MERGE_SHA`, poll
  `gh run view <id> --json status,conclusion` every 30s, timeout 20 min.
  ```bash
  gh run list --branch "$BASE" --limit 10 --json databaseId,headSha,status,conclusion,workflowName \
    | jq ".[] | select(.headSha==\"$MERGE_SHA\")"
  ```
- **Auto-deploy platforms (Vercel, Netlify):** no explicit trigger; sleep 60s,
  then probe the production URL with `curl -sf -o /dev/null -w "%{http_code}" $URL`
  until 200 (cap at 10 min).
- **Platform CLI present (Fly/Heroku/Render/Railway):** if the CLI is installed,
  use its native status command (e.g. `fly status --app <app>`, `heroku releases -n 1`).
  If not installed, fall back to HTTP probe.
- **No platform detected, no URL:** ask the user once via AskUserQuestion: A) provide
  production URL, B) library/CLI — nothing to deploy. If B, jump to Step 6.

If the deploy workflow `conclusion=failure`: stop and offer A) inspect logs
(`gh run view <id> --log-failed`), B) revert (Step 7), C) continue to canary anyway
(deploy step may have been flaky).

If timeout: warn and offer to continue to canary or stop.

## Step 5: Canary verification

Once a production URL is known, run a single-pass health check (this skill checks
once; extended monitoring is out of scope):

```bash
URL="<detected or user-provided>"
# Status
curl -sf -o /dev/null -w "%{http_code}\n" "$URL"
# Latency
curl -sf -o /dev/null -w "%{time_total}\n" "$URL"
# Body sanity
curl -sf "$URL" | head -c 4096
```

Pass criteria:
- HTTP 200 (or expected status for the route).
- Page body is not blank and not a generic error template.
- Total time < 10s.

If a `Deploy` section in `CLAUDE.md`/`AGENTS.md` lists extra healthcheck endpoints
(`/healthz`, `/api/health`, etc.), probe those too.

If anything fails, show the evidence (status, latency, first lines of body) and ask
via AskUserQuestion: A) warming up — mark healthy and continue, B) broken — revert,
C) investigate manually before deciding.

## Step 6: Deploy report

Produce a short report and save it under `.reports/deploy/<date>-pr<number>.md`.
Keep it plain ASCII and brief:

```
LAND & DEPLOY REPORT
PR:        #<n> — <title>
Branch:    <head> -> <base>
Merge SHA: <sha>
Merge:    <auto / direct / queue>
CI wait:  <duration>
Deploy:   <PASSED / FAILED / NO-WORKFLOW / SKIPPED>
Canary:   <HEALTHY / DEGRADED / SKIPPED / REVERTED>
URL:      <url or n/a>
Verdict:  <DEPLOYED AND VERIFIED | DEPLOYED (UNVERIFIED) | REVERTED>
```

## Step 7: Revert (escape hatch, only on user request)

Triggered only when the user picks "revert" at a failure gate.

```bash
git fetch origin "$BASE"
git checkout "$BASE"
git pull --ff-only origin "$BASE"
git revert "$MERGE_SHA" --no-edit
git push origin "$BASE"
```

Use a Conventional Commits message — `git revert --no-edit` produces
`Revert "<original subject>"`, which is acceptable. If commitlint or branch
protection rejects the direct push, create a revert PR instead:

```bash
git checkout -b "revert/pr-<n>"
git revert "$MERGE_SHA" --no-edit
git push -u origin HEAD
gh pr create --title "revert: <original PR title>" --body "Reverts #<n>"
```

If revert has conflicts, surface the SHA and stop — manual resolution required.

After a successful revert, re-run Steps 4–5 to confirm the rollback is live.
Mark the report verdict `REVERTED`.

## Important rules

- **Boundary:** start at merge, end at verified prod (or revert). Don't reach back
  into PR creation or release engineering.
- **Never force push, never skip CI.**
- **Narrate.** Tell the user what just happened, what's happening now, what's next.
  Don't go silent between stages.
- **Auto-detect; ask only when truly ambiguous** (no platform + no URL).
- **Poll with 30s intervals, sane timeouts** (15 min CI, 20 min deploy, 10 min URL probe).
- **Revert is always available** at every failure gate.
- **Single-pass canary, not continuous monitoring.**
- **Idempotent:** re-entering after a partial run skips completed stages via the task list.

## Delegation map

| Concern | Owner |
| --- | --- |
| Release readiness review | `/ship` (run before this skill) |
| Commit + push + PR create | `/create-pr` |
| PR merge command | `/create-pr` scripts (`wait-for-merge.sh`) invoked here |
| Fix broken CI / conflicts on PR | `/pr-pass` |
| Version bump, tag, changelog | `semantic-release` (automatic on base branch) |
| Schema/data migration safety | `/ship` (already evaluated upstream) |
