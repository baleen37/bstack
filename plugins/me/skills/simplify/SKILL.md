---
name: simplify
description: Review the changed code for reuse, simplification, efficiency, and altitude cleanups, then apply the fixes. Quality only — it does not hunt for bugs; use me:code-review for that. Use when the user asks to simplify, clean up, or tidy the current diff without changing behavior.
---

# Simplify

`simplify → 4 cleanup agents in parallel → apply the fixes`

You are improving the quality of the changed code, not hunting for bugs. Review
it for reuse, simplification, efficiency, and altitude issues, then fix what you
find. Do not look for correctness bugs — that is what `me:code-review` is for.

If the invocation carries a target (a PR number, branch name, or path), state
`Review target: <target>` and review that instead of the default diff.

## Tool mapping

This skill runs on Claude Code and Codex. The **subagent tool** is the `Agent`
tool on Claude Code, and spawned subagents (for example `spawn_agent`) on Codex
when multi-agent is enabled. If no subagent tool is available, follow the
_Single-pass fallback_ instead of erroring.

## Phase 0 — Gather the diff

Run `git diff @{upstream}...HEAD` (or `git diff main...HEAD` / `git diff HEAD~1`
if there's no upstream) to get the unified diff under review. If there are
uncommitted changes, or the range diff is empty, also run `git diff HEAD` and
include the working-tree changes in scope — the review often runs before the
commit. If a PR number, branch name, or file path was passed as an argument,
review that target instead (`gh pr diff <n>` for a PR). Treat this diff as the
review scope.

## Phase 1 — Review (4 cleanup agents in parallel)

Launch **4 independent review agents** via the subagent tool, all in a single
message so they run concurrently. Pass each agent the diff and one of the four
angles below, verbatim. Each returns its findings with `file`, `line`, a
one-line `summary`, and the concrete cost (what is duplicated, wasted, or
harder to maintain).

### Reuse

Flag new code that re-implements something the codebase already has — grep
shared/utility modules and files adjacent to the change, and name the existing
helper to call instead.

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

## Phase 2 — Apply the fixes

Wait for all four agents to complete, dedup findings that point at the same
line or mechanism, and fix each remaining one directly. Skip any finding whose
fix would change intended behavior, require changes well outside the reviewed
diff, or that you judge to be a false positive — note the skip rather than
arguing with it. Finish with a brief summary of what was fixed and what was
skipped (or confirm the code was already clean).

## Single-pass fallback (no subagent tool)

The usual 4-agent fan-out can't run. Work through all four angles yourself, in
this same context, in one pass — do not skip an angle for lack of fan-out. For
each, note findings with `file`, `line`, a one-line `summary`, and the concrete
cost. Then apply Phase 2 as written.

State clearly in your summary that this was a single-pass review done without
a subagent tool, not the full 4-agent fan-out, so whoever reads it isn't misled
about what actually ran.
