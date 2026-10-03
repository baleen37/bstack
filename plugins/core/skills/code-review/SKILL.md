---
name: code-review
description: "Review the current diff, or a PR number/branch/path target, for correctness bugs plus reuse/simplification/efficiency/altitude/conventions cleanups in one careful pass. Pass --comment to post findings as inline PR comments, or --fix to apply the findings to the working tree after the review. Use when the user asks to review a diff, branch, or PR."
---

# Code review

`code-review → one careful diff pass → ≤15 ranked findings`

## Arguments

Read the text that follows the skill name in the invocation:

- **`--fix`** — apply the findings after the review (see _Applying fixes_).
- **`--comment`** — post the findings to the PR/MR (see _Posting_).
- **Target** — anything else: a PR number, branch name, or path. Strip a
  leading `#` from a PR number.

State the target you are reviewing on one line before starting.

## Tool mapping

This skill runs on Claude Code and Codex. Where it says:

- **findings tool** — a `ReportFindings` tool, if one is in your tool set.
  Otherwise use the JSON output contract.
- **instruction files** — `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, and
  `AGENTS.override.md`.

Do the whole review yourself in this context. Do not spawn subagents or
delegate the review to another agent — not for finding, not for verifying.

## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead (`gh pr diff <n>` for a PR). Treat this diff as the
review scope.

## Phase 1 — Review

Review the diff as a careful senior engineer would: read every hunk, open the
surrounding files for context as needed (Read, Grep, git log/blame/show), and
hunt for correctness issues first:

- wrong or inverted conditions, off-by-one, null/undefined dereference,
  missing `await`, falsy-zero checks, wrong-variable copy-paste, error
  swallowed in a catch that should propagate
- removed guards or validations — for each deleted or replaced line, name the
  behavior it enforced and check the new code still enforces it
- broken callers of changed functions — grep the symbol and check for a new
  precondition, changed return shape, new exception, or ordering dependency
- races and language pitfalls the diff introduces

Then, in the same pass, look for cleanups in the changed code:

- **Reuse** — new code that re-implements an existing helper; name the helper.
- **Simplification** — redundant or derivable state, copy-paste with slight
  variation, deep nesting, dead code left behind; name the simpler form.
- **Efficiency** — redundant computation or repeated I/O, independent
  operations run sequentially, blocking work on startup or hot paths; name
  the cheaper alternative.
- **Altitude** — a symptom patched with a special case on shared
  infrastructure where a general change to the underlying mechanism would do.
- **Conventions** — a clear violation of an instruction file that governs the
  changed code (user-level, repo-root, or one in an ancestor directory of a
  changed file). Only flag it when you can quote the exact rule and the exact
  line that breaks it; name the file path in the finding.

### What qualifies

Flag an issue only when all of these hold:

1. It meaningfully affects correctness, performance, security, or
   maintainability, and is discrete and actionable.
2. The diff introduced it, or it sits in an unchanged line of a function the
   diff touches. Pre-existing issues elsewhere are out of scope.
3. It does not rely on unstated assumptions about the codebase or intent, and
   it is not clearly an intentional change.
4. A claimed breakage elsewhere names the code that is provably affected —
   speculation that a change "may disrupt" something is not enough.
5. The fix does not demand more rigor than the rest of the codebase shows.
6. The author would fix it if they knew about it.

Ignore style, naming, formatting, typos, and missing tests unless they obscure
meaning or break a documented rule.

Before reporting, re-check each finding against the code once and drop any you
cannot back with a concrete failure scenario. Correctness bugs outrank cleanup,
altitude, and conventions findings when the cap forces a cut.

Report everything that qualifies, up to 15 findings, and nothing that doesn't.
Do not stop at the first qualifying finding. If nothing qualifies, report no
findings — do not pad.

## Output

**With the findings tool:** call it once with `{findings}`. `findings` is at
most 15 entries ranked most-severe first; each entry has `file`, `line`,
`summary`, `short_summary` — the claim compressed to ≤60 characters, no
rationale or consequence clause — `failure_scenario`, and `category` — a short
kebab-case slug for the kind of finding (`correctness`, `simplification`,
`efficiency`, `reuse`, `altitude`, `conventions`, or a more specific slug like
`test-coverage` when one fits better). For cleanup, altitude, and conventions
findings, `failure_scenario` states the concrete cost (what is duplicated,
wasted, harder to maintain, or which instruction-file rule is broken) instead
of a crash. If nothing qualifies, call it with an empty array. After the tool
call, also restate the findings in your final reply — one line each,
`file:line — summary` — so they stay visible in sessions that do not render
tool output.

**Without it:** return findings as a JSON array of at most 15 objects:

```json
[
  {
    "file": "path/to/file.ext",
    "line": 123,
    "summary": "one-sentence statement of the bug",
    "failure_scenario": "concrete inputs/state → wrong output/crash",
    "category": "correctness"
  }
]
```

Ranked most-severe first. If nothing qualifies, return `[]`.

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

Only when `--fix` applied changes: if `core:verify` has NOT run this session and
the diff has a runtime surface (not test-only or docs-only), run `core:verify`
now — this review checks that the diff reads right; `core:verify` checks that it
runs right. Otherwise, do not run it; suggest it in one line if the diff has a
runtime surface.
