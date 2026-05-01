---
name: ship
description: Ship workflow — boil-the-lake review gate that detects base, runs verification, dispatches specialist reviewers, and hands off to /create-pr. Use when asked to "ship", "release", "is this ready to go live?". (based on gstack)
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
  - TaskCreate
  - TaskUpdate
  - TaskList
  - Skill
---

<!--
Based on https://github.com/garrytan/gstack ship/SKILL.md
Adapted to our environment (Bun/BATS, semantic-release, Conventional Commits) with delegation
to /qa, /e2e, /create-pr instead of in-skill QA / push / version management.
-->

# /ship: Fully automated ship workflow

You are running the `/ship` workflow. This is a **non-interactive, fully automated** workflow rooted in gstack's review gate. The user said `/ship` — DO IT. Run straight through, dispatch specialist reviewers in parallel, and hand off to `/create-pr` when ready.

## Relationship to other skills (delegation)

`/ship` does NOT verify implementation details, run E2E flows, push commits, create PRs, bump versions, or edit CHANGELOG. Those are owned by other skills or by the release toolchain:

| Concern | Owner |
| --- | --- |
| Implementation verification (does it work?) | `/qa` |
| Cross-boundary / multi-component flow | `/e2e` |
| Commit, push, PR creation, merge | `/create-pr` |
| Version bump | semantic-release (automatic on merge to main) |
| CHANGELOG | semantic-release (automatic on merge to main) |

`/ship` consumes available evidence from these skills and dispatches its own review specialists. If evidence is missing, ship reports the gap and lowers the decision rather than running the missing skill itself.

## Idempotency and progress tracking

**Re-running `/ship` means "run the whole checklist again."** Every verification step runs on every invocation. Only *actions* skip when already done.

On entry, use `TaskCreate` to register each step below as a task and update with `TaskUpdate` (`in_progress` → `completed`) as you go. On re-run, `TaskList` shows the prior progress — completed steps may be re-verified but actions like "delegate to /create-pr" are no-ops if already done. Do not request per-step confirmation: this is non-blocking, automated execution.

**Only stop for:**
- On the base branch (abort)
- Merge conflicts that cannot be auto-resolved
- In-branch test failures (pre-existing failures are triaged, not auto-blocking)
- Pre-landing review finds ASK items that need user judgment
- Specialist review surfaces a CRITICAL finding that requires a human call
- Plan items NOT DONE with no user override

**Never stop for:**
- Uncommitted changes (always include them)
- Commit message approval (delegated to /create-pr)
- Auto-fixable review findings (dead code, N+1, stale comments — fixed automatically)

## Core principles (from gstack)

- **Boil the Lake.** AI makes completeness cheap. Recommend complete lakes (tests, edge cases, error paths); flag oceans (rewrites, multi-quarter migrations).
- **Confidence calibration.** Every finding has a confidence score 1-10. Confidence < 7 displays with a "verify" caveat. Confidence < 5 is suppressed from the main report.
- **Teacher vs trusted mode.** Default is trusted: run straight through. Only stop for hard gates listed above.
- **Parallel specialists.** Independent reviewers run concurrently — fresh context, no cross-bias.
- **Adaptive gating.** A specialist that has produced 0 findings in 10+ recent reviews is gated off, unless `NEVER_GATE` (security, data-migration).
- **Scope drift detection.** Compare diff vs stated intent. Surface "while I was in there" creep and missing requirements.
- **Confusion protocol.** For high-stakes ambiguity, STOP and present 2-3 options. Do not silently pick.
- **See something, say something.** Flag anything that looks wrong with one sentence — what you noticed and its impact.

---

## Step 0: Detect platform and base branch

Detect the git hosting platform from the remote URL:

```bash
git remote get-url origin 2>/dev/null
```

- URL contains "github.com" → **GitHub**
- URL contains "gitlab" → **GitLab**
- Otherwise check `gh auth status` / `glab auth status`. Neither → **unknown** (git-native commands only).

Determine the base branch:

**GitHub:**
1. `gh pr view --json baseRefName -q .baseRefName` — if succeeds, use it
2. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`

**Git-native fallback:**
1. `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'`
2. `git rev-parse --verify origin/main` → `main`
3. `git rev-parse --verify origin/master` → `master`

Substitute the detected branch wherever instructions reference `<base>`.

---

## Step 1: Pre-flight

1. Check current branch. If on `<base>`, **abort**: "You're on the base branch. Ship from a feature branch."
2. Run `git status` (never `-uall`). Uncommitted changes are always included.
3. Run `git diff <base>...HEAD --stat` and `git log <base>..HEAD --oneline` to understand what is shipping.

---

## Step 2: Merge the base branch (BEFORE tests)

```bash
git fetch origin <base> && git merge origin/<base> --no-edit
```

If complex merge conflicts appear, **STOP** and show them. If already up to date, continue silently.

---

## Step 3: Verification evidence (delegate to /qa and /e2e)

`/ship` does not run tests itself. It inspects evidence produced by `/qa` and `/e2e` and runs the project's standard test command as a final gate.

1. **Run the project test command** (`bats tests/`, `bun test`, or whatever the project uses per `CLAUDE.md`). This is the smoke gate.
   - If failures occur, classify ownership (in-branch vs pre-existing) using the triage in [references/test-triage.md](references/test-triage.md).
   - In-branch failures: **STOP**.
   - Pre-existing failures: triage per the doc, then continue.

2. **Look for `/qa` evidence.** Recent `/qa` reports, screenshots, or browser notes. If the diff has UI changes and `/qa` evidence is missing or stale, recommend running `/qa` and lower the decision (do not run `/qa` from inside `/ship`).

3. **Look for `/e2e` evidence.** If the diff crosses service boundaries / multiple layers / external integrations and `/e2e` has not been run, recommend `/e2e` and lower the decision.

Stale evidence is not a hard blocker by itself. It blocks **Ready** unless the change is low-risk and the stale portion is unrelated.

---

## Step 4: Scope drift detection

Before reviewing code quality: **did the branch build what was requested — nothing more, nothing less?**

1. Read PR description (`gh pr view --json body --jq .body 2>/dev/null || true`), commit messages (`git log <base>..HEAD --oneline`), and any plan file referenced in conversation.
2. Identify **stated intent.**
3. Compare against `git diff <base>...HEAD --stat`.

Evaluate with skepticism:

**SCOPE CREEP:**
- Files changed unrelated to stated intent
- New features / refactors not in the plan
- "While I was in there" changes that expand blast radius

**MISSING REQUIREMENTS:**
- Stated requirements not addressed
- Partial implementations

Output:

```
Scope Check: [CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING]
Intent: <one line — what was requested>
Delivered: <one line — what the diff does>
[If drift: list each out-of-scope change]
[If missing: list each unaddressed requirement]
```

INFORMATIONAL — never blocks. Continue.

---

## Step 5: Pre-landing review (checklist pass)

Read [references/review-checklist.md](references/review-checklist.md). If unreadable, **STOP** and report the error.

Run two passes against `git diff <base>...HEAD`:

- **Pass 1 (CRITICAL):** SQL & data safety, race conditions, LLM output trust boundary, shell injection, enum completeness.
- **Pass 2 (INFORMATIONAL):** all remaining categories in the checklist.

### Confidence calibration

Every finding MUST include a confidence score:

| Score | Meaning | Display rule |
| --- | --- | --- |
| 9-10 | Verified by reading specific code. Concrete bug demonstrated. | Show normally |
| 7-8 | High confidence pattern match. | Show normally |
| 5-6 | Moderate. Could be false positive. | Show with caveat: "Medium confidence, verify" |
| 3-4 | Low. Suppress from main report; appendix only. |
| 1-2 | Speculation. Only report if severity would be P0. |

**Finding format:**

```
[SEVERITY] (confidence: N/10) file:line — description
```

---

## Step 6: Specialist dispatch (parallel review army)

### Detect stack and scope

```bash
# Sub-scope detection (frontend/backend/auth/api/migrations) is project-specific.
# Use git diff to inspect changed paths.
git diff <base> --name-only
DIFF_INS=$(git diff <base> --stat | tail -1 | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
DIFF_DEL=$(git diff <base> --stat | tail -1 | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)
DIFF_LINES=$((DIFF_INS + DIFF_DEL))
echo "DIFF_LINES: $DIFF_LINES"
```

### Select specialists

**Always-on (when DIFF_LINES >= 50):**
1. **Testing** — [references/specialists/testing.md](references/specialists/testing.md)
2. **Maintainability** — [references/specialists/maintainability.md](references/specialists/maintainability.md)

**If DIFF_LINES < 50:** Skip all specialists — too small to be worth the parallel context. Print: "Small diff ($DIFF_LINES lines) — specialists skipped."

**Conditional (dispatch only if scope matches):**
- **Security** — auth/permissions/secrets touched OR (backend changed AND DIFF_LINES > 100). [references/specialists/security.md](references/specialists/security.md). `NEVER_GATE` — always runs when scope matches.
- **Performance** — backend or frontend changed. [references/specialists/performance.md](references/specialists/performance.md).
- **Data Migration** — schema/migration files. [references/specialists/data-migration.md](references/specialists/data-migration.md). `NEVER_GATE`.
- **API Contract** — public API/contract files. [references/specialists/api-contract.md](references/specialists/api-contract.md).

### Adaptive gating

If a specialist has produced 0 findings in 10+ recent reviews on this repo (track in `.ship-stats.jsonl` if helpful), gate it off. **Never gate** Security or Data Migration — they are insurance specialists. Force-include any specialist if the user passes `--security`, `--performance`, etc.

### Dispatch in parallel

Launch every selected specialist as a single message with multiple `Agent` tool calls so they run concurrently with fresh context. Each subagent prompt includes:

1. The specialist checklist content (read the file above and inline it).
2. Stack context (e.g., "This is a Bun/TypeScript project.").
3. Instruction to run `git diff <base>` and emit each finding as a single-line JSON object:

```json
{"severity":"CRITICAL|INFORMATIONAL","confidence":N,"path":"file","line":N,"category":"…","summary":"…","fix":"…","fingerprint":"path:line:category","specialist":"name"}
```

If no findings: output `NO FINDINGS`. Nothing else.

If a specialist subagent fails or times out, log it and continue with results from successful specialists. Specialists are additive.

### Collect and merge

For every finding:

1. Compute `fingerprint = path:line:category` (or `path:category` if no line).
2. Group by fingerprint. When multiple specialists confirm: keep the highest-confidence entry, tag `MULTI-SPECIALIST CONFIRMED (a + b)`, boost confidence by +1 (cap 10).
3. Apply confidence gates (≥7 normal, 5-6 caveat, 3-4 appendix, 1-2 suppressed).
4. PR Quality Score: `max(0, 10 - (critical_count * 2 + informational_count * 0.5))`, capped at 10.

### Red Team (conditional)

Activate one final adversarial subagent if `DIFF_LINES > 200` OR any specialist produced a CRITICAL finding. Pass [references/specialists/red-team.md](references/specialists/red-team.md), the merged findings so far, and ask it to find what they missed. Same JSON output format.

---

## Step 7: Adversarial review (always-on)

Dispatch one Claude adversarial subagent (always runs, fresh context, no checklist bias):

> Read the diff with `git diff <base>`. Think like an attacker and a chaos engineer. Find ways this code will fail in production: edge cases, race conditions, security holes, resource leaks, failure modes, silent data corruption, trust boundary violations. Be adversarial. No compliments — just the problems. For each finding, classify FIXABLE or INVESTIGATE.

FIXABLE findings flow into the same Fix-First pipeline as the checklist + specialist findings. INVESTIGATE findings are presented informationally.

If subagent fails or times out: "Adversarial subagent unavailable. Continuing." (informational only, never blocks).

---

## Step 8: Fix-First flow

Apply the fix-first heuristic from the checklist to every collected finding (checklist pass + specialists + red team + adversarial):

```
AUTO-FIX (apply without asking):           ASK (need human judgment):
- Dead code / unused variables             - Security (auth, XSS, injection)
- N+1 queries (missing eager loading)      - Race conditions
- Stale comments contradicting code        - Design decisions
- Magic numbers → named constants          - Large fixes (>20 lines)
- Missing LLM output validation            - Enum completeness
- Version/path mismatches                  - Removing functionality
- Variables assigned but never read        - Anything changing user-visible behavior
- Inline styles, O(n*m) view lookups
```

Critical findings lean toward ASK. Informational findings lean toward AUTO-FIX.

1. **Auto-fix all AUTO-FIX items.** Output one line per fix: `[AUTO-FIXED] file:line — Problem → action`.
2. **If ASK items remain,** present them in ONE `AskUserQuestion`:
   - Each item: number, severity, problem, recommended fix, per-item options A) Fix B) Skip
   - Overall recommendation
   - 3 or fewer ASK items → individual `AskUserQuestion` calls allowed
3. **After fixes:** if any fixes were applied, the pre-flight evidence is now stale. **STOP** and tell the user to re-run `/ship` to re-verify. If no fixes applied, continue.

Output summary: `Pre-Landing Review: N issues — M auto-fixed, K asked (J fixed, L skipped)`.

---

## Step 9: Verification gate

**IRON LAW: NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

Before handing off:

1. If ANY code changed in Step 8 (auto-fixes), re-run the project test command. Stale output is not acceptable.
2. If the project has a build step, run it.
3. Rationalization prevention:
   - "Should work now" → run it
   - "I'm confident" → confidence is not evidence
   - "I already tested" → code changed since then

If anything fails here, **STOP**. Fix and return to Step 3.

---

## Step 10: Hand off to /create-pr

Do NOT push, commit, or create a PR from inside `/ship`. Invoke the `/create-pr` skill via the `Skill` tool. Pass it the prepared PR body (template below). `/create-pr` owns commit, push, PR creation, and the merge wait.

### PR body template

```markdown
## Summary
<Group commits from `git log <base>..HEAD --oneline` into logical sections.
Every substantive commit must appear. Exclude bookkeeping commits.>

## Pre-Landing Review
<findings from Step 5 + 6 + 7 + 8, or "No issues found.">

## Specialist Review
<merged specialist findings, PR Quality Score>

## Scope Check
<output from Step 4>

## Verification
- [x] Test suite passes (paste fresh output line)
- [x] /qa evidence present <or note absence>
- [x] /e2e evidence present <or note absence / not required>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### Conventional Commits & semantic-release

The project uses **commitlint + semantic-release**. `/create-pr` will create commits — ensure messages follow `type(scope): description` (Conventional Commits). Do **not** edit `VERSION` or `CHANGELOG.md` manually; semantic-release writes them on merge to `main`.

---

## Decision and output

After every step, report using these sections:

### Decision

`Ready / Conditionally ready / Not ready` — one sentence explanation.

Default to **Not ready** when:
- behavior change has no test/verification evidence
- evidence is stale after relevant code changes
- schema/data/auth/security changes lack a recovery story
- a CRITICAL specialist finding is unresolved

### Blocking issues

Items that must be resolved before shipping. Cite evidence or missing evidence.

### Warnings

Risks that don't fully block.

### Readiness dashboard

| Area | Status | Evidence | Gap |
| --- | --- | --- | --- |
| Scope | pass/weak/fail | … | … |
| Tests | pass/weak/fail | … | … |
| QA/E2E | pass/weak/fail | … | … |
| Review | pass/weak/fail | … | … |
| Specialists | pass/weak/fail | PR Quality Score X/10 | … |
| Rollout | pass/weak/fail | … | … |
| Rollback | pass/weak/fail | … | … |
| Monitoring | pass/weak/fail | … | … |

### Risk classification

Highest-risk category among: docs-only, code, UI, schema-data, auth-security, prompt-skill, infra-release.

### Next actions

Smallest set of actions to improve readiness.

---

## Style

Be direct and evidence-based. Lead with the point. Name files, lines, commands. Tie findings to user impact. No filler. No AI vocabulary (delve, crucial, robust, comprehensive, multifaceted, foster, showcase, intricate, vibrant). No em dashes inside prose. If you cannot verify a claim, say so and lower the decision.

## Important rules

- Never run `/qa`, `/e2e`, or `/create-pr` work inline — invoke them via the `Skill` tool or report missing evidence.
- Never edit `VERSION` or `CHANGELOG.md` — semantic-release owns release artifacts.
- Never force push.
- Never bypass pre-commit hooks (commitlint, etc.).
- Always re-verify after auto-fixes.
- Re-running `/ship` re-verifies every step. Only the action handoff to `/create-pr` is idempotent.
- The goal: user says `/ship`, next thing they see is the readiness dashboard plus a `/create-pr` invocation (or a clear stop reason).
