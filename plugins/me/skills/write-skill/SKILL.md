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
all available transcript history for the current Git repository. Treat this as
a **provider source set plus transcript metadata filter**, not as one literal
`--source` value.

- The transcript record is the primary scope evidence. Claude and Codex
  harvesters retain the session `cwd` as the project path; use it to associate
  sessions with the requested repository. Do not enumerate live worktrees as
  the harvest input.
- Run the documented Claude source and Codex source against their transcript
  stores. If the runner accepts only one source per run, run each provider
  separately and filter the resulting task records by their recorded project.
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

## Transcript scope and repository identity

SkillOpt's official CLI makes `--project` the transcript scope and keeps
`--target-skill-path` separate. Its `scope=invoked` is path-based and does not
include sibling worktrees; its `scope=all` means all projects, not this Git
repository. Use the current docs and runner help as the contract.

1. Resolve the target repository with `git rev-parse --show-toplevel` and keep
   the exact target skill path separate from history paths.
2. Read transcript metadata first. Match each session's recorded `cwd` or
   project path to the target repository's Git root/common directory when that
   path is available. Preserve historical paths that no longer exist instead of
   silently dropping them.
3. Use `git worktree list --porcelain` only as a completeness check for current
   paths and as context for reporting. It is not the source-of-truth session
   inventory, because archived transcripts can outlive a worktree.
4. Do not pass `scope=all` and treat its output as repository-scoped. If the
   runner has no repository filter, harvest the provider transcript store with a
   safe read-only path, then filter task records by their recorded project and
   retain the provenance manifest.
5. Codex `archived_sessions` does not include the currently active session in
   the live `sessions` tree. Report that boundary separately from repository
   scope.

An exact target path and a transcript source path are different decisions. Keep
the requested target in the active worktree while importing history identified by
transcript metadata.

## Session evidence and checkpoints

Never conclude “there are no sessions” from a single `dry-run` result.

1. After resolving the repository identity, run the documented read-only
   `harvest` path once per requested provider against the transcript store. Use
   a bounded session/task limit and write the result to an explicit task file
   when supported, then filter by each task's recorded project before replay.
2. Inspect the runner state or `~/.skillopt-sleep/state.json` for the relevant
   project's `last_harvest` checkpoint. This checkpoint is keyed by the
   invoked project path, so it is not a complete repository history index.
3. Treat `last_harvest` as a filter, not proof that history is absent. A
   `lookback-hours=0` option scans all available history for the initial harvest
   but does not reset an existing checkpoint; a stateful `dry-run` can report
   zero after direct harvest found sessions.
4. Before any stateful run, capture direct harvest evidence. For replay, pass
   an explicit harvested and reviewed task file when the runner supports it.
   Preserve provider, transcript project/cwd, session IDs, and task provenance.
5. Classify the outcome precisely: no sessions, sessions with no mined tasks,
   mined tasks rejected by the held-out gate, or the current session not yet
   archived. Do not collapse these into “no evidence”.

Mock validates the mechanics and makes no provider calls. It cannot prove model
improvement. A real backend may send transcript or task content to its provider,
so inspect and redact sensitive evidence and mark it reviewed first.

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
3. Check every requested source independently, using transcript metadata and
   the direct harvest rules above. If all requested sources have no usable
   evidence, ask: “There are no relevant sessions. Should I draft 3–5
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
- evidence scope: current project path or transcript-derived repository scope;
- source/backend for each run, including Claude/Codex provenance;
- provider counts, transcript project/cwd coverage, and checkpoint status;
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
- Treating a sibling worktree as absent because `scope=invoked` searched only the
  active project path. Inspect transcript metadata first.
- Treating a stateful zero-session `dry-run` as proof that no history exists.
- Claiming current-session evidence before Codex archives it.
- Passing `scope=all` without filtering its all-project output by transcript
  project identity.
- Passing a copied or unsupported flag such as `--source opencode`.
- Calling a staged candidate an improvement before its held-out gate passes.
- Running a real backend on unreviewed sensitive transcripts.
- Adopting or overwriting a live skill without showing the exact diff.
