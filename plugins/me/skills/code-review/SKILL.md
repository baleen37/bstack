---
name: code-review
description: "Review the current diff, or a PR number/branch/path target, for correctness bugs plus reuse/simplification/efficiency/altitude/conventions cleanups at a given effort level (low/medium: fewer, high-confidence findings; high→max: broader coverage, may include uncertain findings; default medium). Pass --comment to post findings as inline PR comments, or --fix to apply the findings to the working tree after the review. Use when the user asks to review a diff, branch, or PR."
---

# Code review

`code-review → finder angles → verify → ranked findings`

## Arguments

Read the text that follows the skill name in the invocation:

- **Level** — first token if it is one of `low`, `medium`, `high`, `xhigh`,
  `max`. No level → `medium`. An unrecognized level-like token → say it was
  ignored, list the valid ones, and run at `medium`.
- **`--fix`** — apply the findings after the review (see _Applying fixes_).
- **`--comment`** — post the findings to the PR/MR (see _Posting_).
- **Target** — anything else: a PR number, branch name, or path. Strip a
  leading `#` from a PR number.

State the level and target you are running with on one line before starting.

## Tool mapping

This skill runs on Claude Code and Codex. Where it says:

- **subagent tool** — Claude Code: the `Agent` tool. Codex: spawn subagents
  (for example `spawn_agent`) when multi-agent is enabled. If no subagent tool
  is available, use the _Single-pass fallback_ below instead of erroring.
- **findings tool** — a `ReportFindings` tool, if one is in your tool set.
  Otherwise use the JSON output contract.
- **instruction files** — `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, and
  `AGENTS.override.md`.

## Levels

| Level | Stance | Angles | Candidates per angle | Verify | Sweep | Max findings |
| ----- | ------ | ------ | -------------------- | ------ | ----- | ------------ |
| `low` | quick | one diff pass (see _Low effort_) | — | none | no | 4 |
| `medium` | precision | A–C + 5 cleanup = 8 | 6 | 3-state | no | 8 |
| `high` | recall | A–C + 5 cleanup = 8 | 6 | recall-biased | no | 10 |
| `xhigh` / `max` | recall | A–E + 5 cleanup = 10 | 8 | 3-state, recall mode | yes | 15 |

Lead-in by stance:

- **precision (medium)** — You are reviewing for **precision**: every finding
  you surface should be one a maintainer would act on.
- **recall (high)** — You are reviewing for **recall**: catch every real bug a
  careful reviewer would catch in one sitting. At this level, catching real bugs
  matters more than avoiding false positives. Err on the side of surfacing.
- **recall (xhigh/max)** — You are reviewing for **recall**: catch every real
  bug. Catching real bugs matters more than avoiding false positives — a missed
  bug ships. Err on the side of surfacing.

## Low effort

`low effort → 1 diff pass → no verify → ≤4 findings`

**Turn 1 — read.** One tool call: read the unified diff
(`git diff @{upstream}...HEAD; git diff HEAD` to cover both committed and
uncommitted changes, or `git diff main...HEAD` / the target passed as an
argument). Skip test/fixture hunks (`test/`, `spec/`, `__tests__/`, `*_test.*`,
`*.test.*`, `fixtures/`, `testdata/`) — test-file changes are not reviewed at
this level. No subagents, no full-file reads.

**Turn 2 — findings.** Flag runtime-correctness bugs visible from the hunk
alone: inverted/wrong condition, off-by-one, null/undefined deref where adjacent
lines show the value can be absent, removed guard, falsy-zero check, missing
`await`, wrong-variable copy-paste, error swallowed in a catch that should
propagate. Also flag — still from the hunk alone — new code that duplicates an
existing helper visible in the diff context, and dead code the diff leaves
behind.

Do **not** flag style, naming, perf, missing tests, or anything outside the
hunk.

With the findings tool: report at most **4 findings**, most-severe first, in one
call with `{level, findings}` — each entry has `file`, `line`, `summary`,
`short_summary` (≤60 characters), and `failure_scenario`. If nothing qualifies,
call it with an empty findings array. Do not also print the findings as text.

Without it: output at most **4 findings**, most-severe first, one line each:
`path/to/file.ext:123 — what's wrong and the concrete failure`. If nothing
qualifies, output exactly `(none)`.

Then skip to _Posting_ / _Applying fixes_ if those flags were passed. The phases
below are for `medium` and above.

## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead (`gh pr diff <n>` for a PR). Treat this diff as the
review scope.

## Phase 1 — Find candidates

Run each angle for your level as an **independent finder** via the subagent
tool, all in a single message so they run concurrently. Each surfaces up to the
per-angle candidate count from the _Levels_ table, with `file`, `line`, a
one-line `summary`, and a concrete `failure_scenario`. Give each finder the diff
(or the command to produce it) and its angle text verbatim — finders do not see
this skill.

Pass every candidate with a nameable failure scenario through — finders that
silently drop half-believed candidates bypass the verify step and are the
dominant cause of misses.

At `xhigh`/`max`: do NOT let one angle's conclusions suppress another's — if two
angles flag the same line for different reasons, record both.

### Angle A — line-by-line diff scan

Read every hunk in the diff, line by line. Then Read the enclosing function for
each hunk — bugs in unchanged lines of a touched function are in scope (the PR
re-exposes or fails to fix them). For every line ask: what input, state, timing,
or platform makes this line wrong? Look for inverted/wrong conditions,
off-by-one, null/undefined deref, missing `await`, falsy-zero checks,
wrong-variable copy-paste, error swallowed in catch, unescaped regex metachars.

### Angle B — removed-behavior auditor

For every line the diff DELETES or replaces, name the invariant or behavior it
enforced, then search the new code for where that invariant is re-established.
If you can't find it, that's a candidate: a removed guard, a dropped error
path, a narrowed validation, a deleted test that was covering a real case.

### Angle C — cross-file tracer

For each function the diff changes, find its callers (grep for the symbol) and
check whether the change breaks any call site: a new precondition, a changed
return shape, a new exception, a timing/ordering dependency. Also check callees:
does a parallel change in the same PR make a call unsafe?

### Angle D — language-pitfall specialist (xhigh/max only)

Scan for the classic pitfalls of the diff's language/framework — for example:
JS falsy-zero, `==` coercion, closure-captured loop var; Python mutable default
args, late-binding closures; Go nil-map write, range-var capture; SQL injection;
timezone/DST drift; float equality. Flag any instance the diff introduces.

### Angle E — wrapper/proxy correctness (xhigh/max only)

When the PR adds or modifies a type that wraps another (cache, proxy, decorator,
adapter): check that every method routes to the wrapped instance and not back
through a registry/session/global — e.g. a caching provider holding a
`delegate` field that resolves IDs via `session.get(...)` instead of
`delegate.get(...)` will re-enter the cache or recurse. Also check that the
wrapper forwards all the methods the callers actually use.

### Reuse

The angles above hunt for bugs; this one and the next two hunt for cleanup in
the changed code. Flag new code that re-implements something the codebase
already has — grep shared/utility modules and files adjacent to the change,
and name the existing helper to call instead.

### Simplification

Flag unnecessary complexity the diff adds: redundant or derivable state,
copy-paste with slight variation, deep nesting, dead code left behind. Name
the simpler form that does the same job.

### Efficiency

Flag wasted work the diff introduces: redundant computation or repeated I/O,
independent operations run sequentially, blocking work added to startup or
hot paths. Also flag long-lived objects built from closures or captured
environments — they keep the entire enclosing scope alive for the object's
lifetime (a memory leak when that scope holds large values); prefer a
class/struct that copies only the fields it needs. Name the cheaper
alternative.

### Altitude

Check that each change fixes the root cause at the right depth rather than
patching a symptom with a fragile bandaid. Special cases layered on shared
infrastructure are a sign the fix isn't deep enough — prefer the simpler, more
general change to the underlying mechanism over adding special cases, and name
that change.

### Conventions (instruction files)

Find the instruction files that govern the changed code: the user-level
`~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, the repo-root `CLAUDE.md` and
`AGENTS.md`, plus any `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, or
`AGENTS.override.md` in a directory that is an ancestor of a changed file (a
directory's file only applies to files at or below it). Read each one that
exists, then check the diff for clear violations of the rules they state.

Only flag a violation when you can quote the exact rule and the exact line
that breaks it — no style preferences, no vague "spirit of the doc"
inferences. In the finding, name the instruction file path and quote the rule
so the report can cite it. If no instruction file applies, return nothing for
this angle.

Cleanup, altitude, and conventions candidates use the same
`file`/`line`/`summary` shape; in `failure_scenario`, state the concrete
cost (what is duplicated, wasted, harder to maintain, or which instruction-file
rule is broken) instead of a crash. Correctness bugs always outrank cleanup,
altitude, and conventions findings when the output cap forces a cut.

## Phase 2 — Verify

Dedup near-duplicates (same defect, same location, same reason → keep one,
the one with the most concrete failure scenario). For each remaining candidate,
run **one verifier** via the subagent tool: give it the diff, the relevant
file(s), and the candidate; it returns exactly one of:

- **CONFIRMED** — can name the inputs/state that trigger it and the wrong
  output or crash. Quote the line.
- **PLAUSIBLE** — mechanism is real, trigger is uncertain (timing, env,
  config). State what would confirm it.
- **REFUTED** — factually wrong (code doesn't say that) or guarded elsewhere.
  Quote the line that proves it.

At `high`, verifiers are **recall-biased** — include this in their prompt:

> **PLAUSIBLE by default** — do not refute a candidate for being "speculative"
> or "depends on runtime state" when the state is realistic: concurrency races,
> nil/undefined on a rare-but-reachable path (error handler, cold cache, missing
> optional field), falsy-zero treated as missing, off-by-one on a boundary the
> code does not exclude, retry storms / partial failures, regex/allowlist that
> lost an anchor. These are PLAUSIBLE.
>
> **REFUTED** only when constructible from the code: factually wrong (quote the
> actual line); provably impossible (type/constant/invariant — show it); already
> handled in this diff (cite the guard); or pure style with no observable effect.

Keep **CONFIRMED and PLAUSIBLE**. Drop REFUTED.

At `xhigh`/`max`: this is recall mode — a single non-REFUTED vote carries the
finding. Do NOT drop on uncertainty.

## Phase 3 — Sweep for gaps (xhigh/max only)

Run **one more finder** as a fresh reviewer who has the verified list. Re-read
the diff and enclosing functions looking ONLY for defects not already listed.
Do not re-derive or re-confirm anything already there — the job is gaps. Focus
on what the first pass tends to miss: moved/extracted code that dropped a guard
or anchor; second-tier footguns (dataclass default evaluated once, `hash()`
non-determinism, lock-scope shrink, predicate methods with side effects);
setup/teardown asymmetry in tests; config defaults flipped.

Surface **up to 8 additional candidates**, each naming a defect not already on
the list. If nothing new, return an empty sweep — do not pad.

## Single-pass fallback (no subagent tool)

The usual multi-agent fan-out and subagent verify pass can't run. Work through
every angle for your level yourself, in this same context, in one pass — do not
skip angles for lack of fan-out. Re-check each candidate against the diff before
keeping it; drop anything you can't back up with a concrete failure scenario.
At `xhigh`/`max`, still do the Phase 3 sweep yourself as a fresh pass.

State clearly in your summary that this was a single-pass review done without
a subagent tool, not the full multi-agent fan-out, so whoever reads it isn't
misled about what actually ran.

## Output

**With the findings tool:** call it once with `{level, findings}`. `findings` is
at most the level's max entries ranked most-severe first; each entry has
`file`, `line`, `summary`, `short_summary` — the claim compressed to ≤60
characters, no rationale or consequence clause — `failure_scenario`, and
`category` — a short kebab-case slug for the angle that produced it
(`correctness`, `simplification`, `efficiency`, `reuse`, `altitude`,
`conventions`, or a more specific slug like `test-coverage` when one fits
better) — plus `verdict` when a verify pass produced one. If nothing survives
verification, call it with an empty array. Do not also print the findings as
text.

**Without it:** return findings as a JSON array of at most the level's max
objects:

```json
[
  {
    "file": "path/to/file.ext",
    "line": 123,
    "summary": "one-sentence statement of the bug",
    "failure_scenario": "concrete inputs/state → wrong output/crash",
    "category": "correctness",
    "verdict": "CONFIRMED"
  }
]
```

Ranked most-severe first. If more than the max survive, keep the most severe.
If nothing survives verification, return `[]`.

## Posting (--comment)

After producing the findings list:

- **GitHub PR target** — post each finding as an inline PR comment (one per
  finding; include a suggestion block only when it fully fixes the issue). Use
  an inline-comment tool if one is available; otherwise
  `gh api repos/{owner}/{repo}/pulls/{pr}/comments`. If neither works, print the
  findings instead.
- **GitLab MR target** — post the findings as one general MR note via
  `glab mr note <iid> -m "<body>"` (every finding with its file:line, the issue,
  and the suggested fix). Line-anchored threads need
  `glab api projects/:id/merge_requests/:iid/discussions`; only do that if the
  user asks. If glab is not available, print the findings instead.
- **Not a PR/MR** — print the findings and note that `--comment` was ignored.

## Applying fixes (--fix)

After producing the findings list, apply the findings to the working tree
instead of stopping at the report: fix each one directly — correctness bugs and
reuse/simplification/efficiency cleanups alike. Skip any finding whose fix would
change intended behavior, require changes well outside the reviewed diff, or
that you judge to be a false positive — note the skip rather than arguing with
it.

With the findings tool: call it again with the same findings, each carrying an
`outcome`: `fixed`, `no_change_needed` (the finding was wrong or already
handled), or `skipped` (real but not applied); then give one line per skipped
finding saying why. Without it: finish with a brief summary of what was fixed
and what was skipped.

## If findings are fixed later

With the findings tool: whenever reported findings get fixed later in this
session — the user asks you to fix them, or later work fixes them incidentally
— call it again with the same findings, each carrying an `outcome` as above.
Make that call immediately after the fixes land, before any prose summary. Do
not repeat the findings as text.

## After the review

After the findings are reported (and applied, when `--fix` was passed): if
`me:verify` has NOT run this session and the diff has a runtime surface (not
test-only or docs-only), run `me:verify` now — this review checks that the diff
reads right; `me:verify` checks that it runs right. State which you did.
