# SkillOpt / SkillOpt-Sleep

Upstream: [microsoft/SkillOpt](https://github.com/microsoft/SkillOpt) (MIT).

Confirm it is runnable before planning anything. `~/.skillopt-sleep/` can hold
config, state, and evidence from an install that is now gone, so its presence
proves nothing:

```bash
python -m skillopt_sleep --help || echo "not available here"
```

If that fails, either `pip install skillopt` (gives the CLI and the engine) or
run `python -m skillopt_sleep` from a source checkout. The wheel is enough for
everything below; only the per-harness plugin wrappers are repo-only. On Nix or
another managed Python, a checkout avoids fighting the environment.

Say it is not installed rather than writing commands that cannot run.

Sleep mines past sessions, replays them, and stages a skill edit behind a
held-out validation gate. It does not target a skill you name; it follows
whatever the sessions contain.

So check for evidence before spending anything. Run `harvest --output` first and
read the mined intents: if fewer than ~3 relate to your skill, Sleep has nothing
to learn from and a real run will burn provider calls to change nothing. Splits
need at least 2 tasks to hold anything out. Write representative tasks by hand
instead.

## Contents

- [Keep these separate](#keep-these-separate)
- [Verified traps](#verified-traps)
- [Working commands](#working-commands)
- [Cost and safety](#cost-and-safety)
- [Protected regions](#protected-regions)
- [Reporting](#reporting)

## Keep these separate

- **source** — where session evidence is read (`claude|codex|cursor|auto`)
- **backend** — what mines, replays, judges (`mock|claude|codex|copilot|cursor|handoff|azure_openai`)
- **target harness** — where the skill will run
- **target path** — the exact SKILL.md that may be staged

## Verified traps

Checked against the runner on 2026-08-04. Re-verify against `--help`; report a
mismatch before a real run.

**`--source auto` is not a union.** It takes Codex, then Claude, and stops at
the first that answers. It never selects Cursor. Observed in one worktree:

| source | result |
| --- | --- |
| `claude` | 5 sessions → 3 tasks |
| `codex` | 1 session → 0 tasks |
| `auto` | 1 session → 0 tasks |

It fails silently. Zero tasks is not evidence that history is absent. Run each
provider separately and merge reviewed task files.

**`--scope invoked` matches parent directories.** `_project_matches()` in
`harvest.py` accepts a session when either path is a prefix of the other, so
sessions recorded in `~` or `~/dev` are pulled into a repo-scoped harvest:

```text
_project_matches("/Users/me", "invoked", "/Users/me/dev/repo")  -> True
```

It also misses sibling worktrees outside the invoked path. Measured on the same
transcript store:

| scope | sessions | projects actually matched |
| --- | --- | --- |
| `invoked` = worktree | 9 | the worktree **+ `~`** |
| `invoked` = main repo | 12 | 2 worktrees **+ `~` + `~/dev`** |
| explicit path list | 5 | exactly the listed paths |

**`--scope` only accepts `all|invoked`.** The underlying config key `projects`
also takes a list of absolute paths, and that is the only clean way to cover
worktrees scattered across different parents. It is reachable through
`~/.skillopt-sleep/config.json` only:

```json
{ "projects": ["/abs/main-repo", "/abs/worktrees/a", "/abs/worktrees/b"] }
```

There is no env var to point at a different config home, so this is global
state. Restore it when done.

**`--scope all` means all projects**, not this repository. Filter its output by
each task's recorded project.

**Codex `archived_sessions` excludes the live session.** The current session is
not harvestable yet. Report that separately from "no history".

**`last_harvest` in `~/.skillopt-sleep/state.json`** is keyed by invoked path,
so it is not a repository-wide index. `--lookback-hours 0` scans all history but
does not reset the checkpoint. A stateful `run` advances it even with zero mined
tasks. The default initial window is 72 hours.

Note the precedence (`cycle.py`): an existing checkpoint **wins over**
`--lookback-hours`. The lookback window applies only when a path has no
checkpoint yet. So on a path that has been harvested before,
`--lookback-hours 0` does not re-scan all history — it resumes from the
checkpoint. To genuinely re-scan, remove that path's `last_harvest` entry.
Back up `state.json` first; it also holds the night history and staging
pointers you need to roll back.

Entries for deleted worktrees are otherwise harmless.

**Cursor** reads `~/.cursor/projects/*/agent-transcripts/*/*.jsonl`. Its backend
runs read-only Ask mode in an empty temp workspace, so it cannot inspect your
repo — textual guidance only, no end-to-end validation. Tool-aware replay is
disabled; a task with a `tool_called` check exits nonzero.

**OpenCode is not supported.** Do not pass `--source opencode`. The repo ships
an OpenClaw reference adaptation, which is a different thing.

## Working commands

```bash
# what is actually supported right now
python -m skillopt_sleep --help

# read-only, per provider, writing a task file for review
python -m skillopt_sleep harvest --project "$(git rev-parse --show-toplevel)" \
  --source claude --scope invoked --lookback-hours 0 \
  --max-sessions 5 --max-tasks 3 --output claude.json

# replay a reviewed task file instead of harvesting
python -m skillopt_sleep dry-run --tasks-file reviewed.json \
  --target-skill-path plugins/me/skills/<name>/SKILL.md

python -m skillopt_sleep status   # state + latest staged proposal
python -m skillopt_sleep adopt    # apply the staged proposal
```

Prefer `harvest` and `dry-run` over `run`. `run` is stateful and advances the
harvest checkpoint even when it mines zero tasks, which makes the next attempt
worse.

## Every worktree, both providers

The goal most people actually want. `--scope` cannot express it; this can.

Worktrees scattered under different parents are unreachable from any single
`invoked` path, so list them explicitly.

```bash
# 1. collect the paths
git worktree list --porcelain | awk '/^worktree /{print $2}'

# 2. back up the global config before touching it
cp ~/.skillopt-sleep/config.json ~/.skillopt-sleep/config.json.bak

# 3. add "projects": ["/abs/a", "/abs/b", ...] to that file, then harvest
#    each provider separately — auto will not do both.
#    --lookback-hours 0 only reaches full history on paths with no checkpoint;
#    clear their last_harvest entries first if you need older sessions.
python -m skillopt_sleep harvest --source claude --lookback-hours 0 \
  --max-sessions 40 --max-tasks 10 --output claude.json
python -m skillopt_sleep harvest --source codex  --lookback-hours 0 \
  --max-sessions 40 --max-tasks 10 --output codex.json

# 4. restore the config
mv ~/.skillopt-sleep/config.json.bak ~/.skillopt-sleep/config.json
```

The file is `{format, project, transcript_source, n_sessions,
target_skill_path, reviewed, tasks[]}`. `transcript_source` is **file-level**,
and tasks carry `project` but not their provider, so concatenating loses it.
Copy it into each task before merging:

```python
out = {"format": "skillopt_sleep.tasks.v1", "project": ROOT,
       "transcript_source": "claude+codex", "reviewed": True, "tasks": []}
for f in ("claude.json", "codex.json"):
    d = json.load(open(f))
    for t in d["tasks"]:
        t.setdefault("tags", []).append(f"source:{d['transcript_source']}")
        out["tasks"].append(t)
```

Then replay the merged file with `dry-run --tasks-file`. Splits are assigned on
load, so one merged file gives one holdout split — that is what lets you report
a single combined score. Two separate runs do not.

`--max-sessions` is a **global cap, not per project**. With 3 paths and
`limit=2`, harvest returned 2 sessions from 1 project and dropped the rest
silently. Scale it to the number of worktrees and confirm the projects you
expect actually appear in the output file, or whole worktrees vanish without a
warning.

Drop tasks whose `project` is outside your worktree list before replaying; the
parent-directory leak above puts `~` sessions in the file. Setting
`"reviewed": true` documents your review; the loader does not enforce it.

Skill-only evolution, in `~/.skillopt-sleep/config.json`:

```json
{ "evolve_memory": false, "evolve_skill": true, "gate_mode": "on" }
```

`schedule` records only project, backend, time, and auto-adopt. It drops source,
model, and target path — put those in the config first.

## Cost and safety

`dry-run` suppresses staging, adoption, and state changes. It does **not**
suppress spend: with a real backend it still makes provider calls. Session and
task limits bound the workload, not tokens or money. Only `mock` makes no calls.

A real backend may send transcript content to its provider. For sensitive work,
harvest to a task file, inspect and redact it, then replay only that file.

## Protected regions

A trained skill may contain machine-managed regions that ordinary edits cannot
touch. Preserve the markers when copying or hand-editing:

```markdown
<!-- SLOW_UPDATE_START --> ... <!-- SLOW_UPDATE_END -->
<!-- APPENDIX_START --> ... <!-- APPENDIX_END -->
```

## Rolling back an adopt

`adopt` copies the live file to `<staging_dir>/backup/` before overwriting it.
`status` prints the staging directory; the history in
`~/.skillopt-sleep/state.json` records one per night.

```bash
python -m skillopt_sleep status                     # find the staging dir
cp <staging_dir>/backup/SKILL.md <live skill path>  # restore
```

If the skill is in git, `git diff` and `git checkout` are simpler and cover the
protected regions correctly. Commit before adopting.

## Reporting

Report: mode, target path and harness, evidence scope, source and backend per
run, provider counts and checkpoint status, baseline vs candidate with the
split, gate result, staged diff, runner version, and whether the change is
staged or adopted.

Adoption is a separate explicit action. Never overwrite a live skill silently.
