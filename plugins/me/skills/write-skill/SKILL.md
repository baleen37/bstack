---
name: write-skill
description: Use when creating or improving an agent skill with SkillOpt, SkillOpt-Sleep, benchmark tasks, or provider session history.
---

# Write Skills with SkillOpt

Use SkillOpt to create or improve a bounded `SKILL.md`. Keep the target
harness, evidence source, backend, validation split, and adoption state explicit.

## Resolve the current surfaces

Before choosing a command or flag:

1. Resolve one exact `target-skill-path` and its target harness.
2. Prefer the local checkout from `SKILLOPT_SLEEP_REPO` or the discovered
   runner. Read its current `README.md`, `docs/index.md`,
   `docs/sleep/README.md`, and the active provider integration README.
3. Inspect the installed runner's current `--help`. Use only flags it exposes.
4. If the checkout and runner disagree, report both versions and stop before a
   real run until the interface is clear.

Record the SkillOpt source URL and commit/version, runner, source provider,
backend, target harness, target path, and selected mode.

Keep these concepts separate:

- `source`: where session or task evidence is read;
- `backend`: which model or CLI mines, replays, judges, or reflects;
- target harness: where the skill will run;
- target path: which exact `SKILL.md` may be staged or adopted.

## Choose the evidence path

| Evidence | Path |
| --- | --- |
| Benchmark tasks, scorer, and train/selection split | SkillOpt core training/evaluation |
| Relevant provider sessions with recurring failures or feedback | SkillOpt-Sleep |
| Neither usable sessions nor a reproducible scorer | Offer 3–5 representative tasks and success criteria for review |

Do not invent a scorer, held-out result, or optimization path. Sleep is not a
substitute for a benchmark when the user expects a benchmark claim.

## Collect Claude and Codex together

When the user asks to learn from both Claude and Codex, collect the union of
all available history from both providers for the current Git repository. Treat
this as a **provider source set plus repository worktree scope**, not as one
literal `--source` value.

- Run the documented Claude source and Codex source for every worktree belonging
  to the repository. If the runner accepts only one source or project per run,
  execute that provider × worktree matrix separately.
- Keep each task's provider, project/worktree, and session provenance in the
  task metadata or reviewed evidence manifest.
- If any requested source has no usable evidence, label the source set partial;
  do not call it a Claude+Codex result.
- Merge the reviewed task records before replay only through a documented
  task-file or multi-source surface. The harvest output keeps
  `transcript_source` at file level, so copy provider and worktree into each
  task or keep a task-id sidecar manifest before concatenating files. Validate
  the merged schema and provenance.
- Claim a combined score only when the merged set has one documented holdout
  split. Otherwise report the Claude and Codex results separately.
- `source=auto` is a fallback policy, not a union. It may select Codex and skip
  Claude when Codex tasks exist.
- Current SkillOpt source support must come from the current docs and help. Do
  not pass `--source opencode` unless the runner explicitly supports it.

Provider target paths are separate from history sources:

- Claude: project `.claude/skills/<name>/SKILL.md`;
- Codex: project `.agents/skills/<name>/SKILL.md`;
- OpenCode: project `.opencode/skills/<name>/SKILL.md` when targeting OpenCode;
  current SkillOpt source support may still be absent;
- bstack source: the exact repository path requested by the user, such as
  `plugins/me/skills/<name>/SKILL.md`.

## Worktree scope

Resolve the current worktree before harvesting:

1. Use `git rev-parse --show-toplevel` for the exact project path.
2. Use `git worktree list --porcelain` to enumerate every worktree of this Git
   repository. Include all listed worktrees for a repository-wide request.
3. Match provider transcripts by their recorded `cwd`, using the exact
   worktree path for each harvest. Do not substitute the main checkout path for
   a sibling worktree.
4. Codex `archived_sessions` does not include the currently active session in
   the live `sessions` tree. Report that boundary even in an all-worktree run.
5. Do not use `scope=all`: it includes unrelated repositories. If the runner
   lacks a repository-worktree scope, run the provider × worktree matrix and
   merge the reviewed task files instead.

An exact target path and a session source path are different decisions. Keep the
requested target in the active worktree while importing history from the other
worktrees.

## Create a new skill

1. Resolve the skill name, purpose, target harness, installation path, task
   examples, and checkable success signal.
2. If examples or a success signal are missing, offer the representative-task
   draft before creating a seed.
3. Use a minimal valid seed when session history is the evidence source.
4. Start with the documented no-provider or mock path. Use a real backend only
   after the user opts in.
5. Validate the accepted artifact on held-out work before presenting it as an
   improvement.

## Improve an existing skill

1. Resolve exactly one target skill and read its current behavior.
2. Define what must remain true and what failure the change addresses.
3. Check every requested source independently. If all requested sources have no
   usable evidence, ask: “There are no relevant sessions. Should I draft 3–5
   representative tasks with success criteria for your review?”
4. Run a dry-run or mock pass first when supported. Session/task limits select
   evidence; they are not hard token, time, or cost budgets.
5. For skill-only evolution, use documented settings that disable memory
   evolution, enable skill evolution, and keep the validation gate on.
6. Review baseline and candidate scores, split, gate action, rejected edits,
   exact diff, and evidence before adoption.

For sensitive projects, harvest to a task file, inspect and redact it, mark it
reviewed, and replay only that reviewed file. Treat local evidence logs as
sensitive. A real backend may send truncated transcript or task content to its
provider; mock makes no provider calls.

## Validate and adopt

For a provider-neutral claim, evaluate the same seed or candidate separately in
each requested target harness. Call it provider-neutral only when every
requested held-out gate passes. Otherwise report provider-specific results.

Never silently overwrite a live skill. Keep generated changes staged until the
user adopts them. Report:

- mode: new or improve;
- exact target path and target harness;
- source/backend for each run, including Claude/Codex provenance;
- baseline and candidate scores with their split, or why no score exists;
- gate result, rejected edits, staged diff, and evidence path;
- source/runner version and any interface mismatch;
- staged versus explicitly adopted state and the next action.

For existing skills, adoption is a separate explicit action and must preserve a
backup when the integration provides one. For new skills, distinguish seed
creation from generated changes.

## Common mistakes

- Treating `source`, `backend`, target harness, and target path as the same thing.
- Treating `source=auto` as Claude+Codex union.
- Claiming current-session evidence before Codex archives it.
- Widening from a worktree to sibling worktrees or all projects without consent.
- Passing a copied or unsupported flag such as `--source opencode`.
- Calling a staged candidate an improvement before its held-out gate passes.
- Running a real backend on unreviewed sensitive transcripts.
- Adopting or overwriting a live skill without showing the exact diff.
