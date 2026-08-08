---
name: autoresearch
description: Set up and run an autonomous experiment loop for any optimization target. Use when asked to "run autoresearch", "optimize X in a loop", "set up autoresearch for X", or "start experiments".
---

# Autoresearch

Autonomous experiment loop: try ideas, keep what works, revert what doesn't, never stop.

Modeled on [karpathy/autoresearch](https://github.com/karpathy/autoresearch), generalized from
"optimize `val_bpb` in `train.py`" to any metric in any repo.

## Setup

1. Ask (or infer): **Goal**, **Command**, **Metric** (+ direction), **Files in scope**, **Constraints**.
2. `git checkout -b autoresearch/<goal>-<date>`
3. Read the source files. Understand the workload deeply before writing anything.
4. `mkdir -p .autoresearch`, then write `.autoresearch/autoresearch.md` and `.autoresearch/run.sh`. Commit both.
5. Run the baseline → log it as the first `results.tsv` row → start looping immediately.

### `autoresearch.md`

This is the heart of the session — upstream's `program.md`. A fresh agent with no context should be
able to read this file and run the loop effectively. Invest time making it excellent.

```markdown
# Autoresearch: <goal>

## Objective
<Specific description of what we're optimizing and the workload.>

## Metrics
- **Primary**: <name> (<unit>, lower/higher is better)
- **Secondary**: <name>, <name>, ...

## How to Run
`./.autoresearch/run.sh` — outputs `METRIC name=number` lines.

## Files in Scope
<Every file the agent may modify, with a brief note on what it does.>

## Off Limits
<What must NOT be touched.>

## Constraints
<Hard rules: tests must pass, no new deps, etc.>

## What's Been Tried
<Update as experiments accumulate. Note key wins, dead ends, and architectural
insights so the agent doesn't repeat failed approaches.>
```

Update the "What's Been Tried" section as you go — that is what a resuming agent reads first.

### `.autoresearch/run.sh`

Bash script (`set -euo pipefail`) that: pre-checks fast (syntax errors in <1s), runs the benchmark,
outputs `METRIC name=number` lines. Keep it fast — every second is multiplied by hundreds of runs.
Update it during the loop as needed.

---

## The Loop

Each iteration: modify files in scope → run the benchmark → parse the metric → keep or revert → log a row.

### 1. Run the benchmark

```bash
bash -c "./.autoresearch/run.sh" 2>&1 | tee /tmp/autoresearch-output.txt
EXIT_CODE=${PIPESTATUS[0]}
```

`EXIT_CODE` must come from `${PIPESTATUS[0]}`, not `$?`. After a pipeline, `$?` holds `tee`'s status
— which is 0 even when the benchmark crashed — so every crash would be logged as a valid result.
Run this under `bash`; in zsh the equivalent is `${pipestatus[1]}`.

Then parse the `METRIC name=number` lines from the output, and read the output to understand what happened.

### 2. Decide status

- **keep**: primary metric improved (lower if lower-is-better, higher if higher-is-better)
- **discard**: primary metric worse or equal to the best kept result
- **crash**: `EXIT_CODE != 0`

**Noisy metrics:** if the metric is stochastic (LLM-judge scores, sampling-based benchmarks), a
single run cannot distinguish signal from noise. Establish the run-to-run variance early, then
average N≥3 runs per experiment and only `keep` when the improvement clearly exceeds that noise
band. A change within the noise band is a `discard`, not a `keep`.

**Before any `keep`, confirm the metric improved because the work got faster/better — not because
the work stopped happening.** A large unexplained win usually means the benchmark got weakened:
cached results, skipped iterations, shrunk input, or a loosened check. If you can't explain *why*
the number moved, `discard` it and investigate instead.

Secondary metrics are for monitoring only. Only discard a primary improvement if a secondary metric
degraded catastrophically, and say why in the description.

### 3. Keep or revert

**If keep** — advance the branch:

```bash
git add -A && git commit -m "<description>"
git rev-parse --short=7 HEAD    # hash for the log row
```

**If discard or crash** — reset back to where you started:

```bash
git reset --hard HEAD && git clean -fd
```

Use the current HEAD hash for the log row.

### 4. Log one row to `results.tsv`

Append to `.autoresearch/results.tsv` — tab-separated, NOT comma-separated (commas break in
descriptions). This file is the source of truth for resuming.

Header row plus one row per experiment:

<!-- markdownlint-disable MD010 -->

```tsv
commit	<metric>	status	description
a1b2c3d	0.997900	keep	baseline
e4f5a6b	0.991200	keep	widen mlp, drop bias terms
a1b2c3d	1.004500	discard	try rotary embeddings
```

<!-- markdownlint-enable MD010 -->

The separators above are literal tab characters.

Add a column per secondary metric you track, right after the primary metric. Once a column exists,
fill it on every subsequent row.

---

## Loop Rules

**LOOP FOREVER.** Never ask "should I keep going?" or "is this a good stopping point?" — the loop
runs until the human interrupts you, period.

- **Primary metric is king.** Improved → `keep`. Worse/equal → `discard`.
- **Simpler is better.** A modest win from deleting code beats an equal win from adding complexity.
  Removing code for equal performance = keep.
- **Don't thrash.** Repeatedly reverting the same idea? Try something structurally different.
- **Crashes:** fix if trivial, otherwise log and move on. Don't over-invest.
- **Think longer when stuck.** Re-read the source, study the profiling data, reason about what the
  machine is actually doing. The best ideas come from deep understanding, not random variation.
- **Resuming:** read `.autoresearch/autoresearch.md` + `.autoresearch/results.tsv` + git log, then
  continue looping.

**NEVER STOP.** The user may be away for hours. Keep going until interrupted.

### Who drives the loop

By default *you* drive it: keep experimenting in this session until interrupted. The loop then ends
when the context window fills up.

For unattended runs longer than one context window, let the **shell** drive it instead — each
iteration gets a fresh context, and the resume path above rebuilds state from `.autoresearch/` plus
git log:

```bash
while :; do
  claude -p "Resume the autoresearch loop in .autoresearch/ and run the next experiment." \
    --permission-mode acceptEdits
done
```

**The loop is only useful if each iteration actually loads this skill** — otherwise the agent
improvises without the keep/discard protocol and the ledger goes unwritten. Two things break it:
`--bare` skips skill discovery entirely, and a prompt that doesn't name this skill may match a
different one. So run a single iteration by hand first and confirm it appended a row to
`.autoresearch/results.tsv` before leaving the loop unattended. If it didn't, name the skill
explicitly in the prompt or pass `--plugin-dir <path-to-autoresearch-plugin>`.

## Ideas Backlog

When you find a promising optimization too complex to try right now, append it to
`.autoresearch/ideas.md` as a checkbox bullet: `- [ ]` untried, `- [x]` tried. Mark an idea `- [x]`
as soon as you try it, keep or discard either way. Don't let good ideas get lost, and don't retry
one you already spent a run on.

If the loop stops (context limit, crash) and `.autoresearch/ideas.md` exists, you'll be asked to
work the unchecked entries, prune ones that are duplicated or clearly bad, and experiment on what's
left. When nothing is left, come up with your own new ideas. When all paths are exhausted, delete
the file and write a final summary.

## User Steers

A user message that arrives mid-experiment goes into the NEXT experiment. Finish the current one
first — don't stop or ask for confirmation.
