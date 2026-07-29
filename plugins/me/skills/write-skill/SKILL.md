---
name: write-skill
description: Use when creating a new agent skill or improving an existing SKILL.md with Microsoft's SkillOpt or SkillOpt-Sleep, including requests to learn from Claude/Codex sessions, train against scored tasks, or produce a validation-gated skill proposal.
---

# Write Skills with SkillOpt

Use Microsoft SkillOpt as the optimization engine for agent skills. Keep the
target model and provider harness explicit, make text edits bounded, validate
on held-out work, and keep generated changes staged until the user adopts them.

## Source of truth

Do not copy SkillOpt commands or flags into this skill as a permanent reference.
SkillOpt is changing. At the start of every run:

1. Prefer the local source checkout from `SKILLOPT_SLEEP_REPO` or the discovered
   SkillOpt runner.
2. Read the current `README.md`, `docs/index.md`, the relevant
   `docs/sleep/README.md`, and the active provider integration README when
   present. For Claude, inspect `plugins/claude-code/README.md` and its bundled
   skill/runner; for Codex, inspect `plugins/codex/README.md` and its bundled
   skill/runner.
3. Inspect the installed runner's current `--help` before choosing commands or
   flags.
4. If no local checkout is available and network access exists, read the
   current `https://github.com/microsoft/SkillOpt` repository.
5. Record the source URL, commit/version, runner, provider, target path, and
   selected mode in the final report.

If the guide and installed runner disagree, report the mismatch. Use only
commands confirmed by the discovered runner; stop before a real run when the
interface cannot be resolved.

## Choose the optimization path

| Evidence and goal | Path |
| --- | --- |
| New skill with a task dataset, checkable scorer, and train/selection split | SkillOpt core training/evaluation |
| Existing skill whose failures are visible in Claude/Codex sessions | SkillOpt-Sleep |
| Existing or new skill with a reproducible benchmark and scorer | SkillOpt core training/evaluation |
| No scorer, held-out split, or usable session history | Offer to draft representative tasks and success criteria for user review; do not silently choose a seed path |

SkillOpt core training treats the skill document as trainable text:

```text
target rollout → optimizer reflection → aggregate/select bounded edits
→ update skill → held-out validation gate → best_skill.md
```

SkillOpt-Sleep treats agent history as the training source:

```text
harvest transcripts → mine recurring tasks → replay
→ consolidate bounded edits → held-out gate → stage proposal → adopt
```

Do not use Sleep as a substitute for a scorer when the user expects a
benchmark claim. Do not invent a scorer or held-out result.

## New skill

1. Resolve the skill name, purpose, target provider/harness, installation path,
   task examples, and success signal.
   If task examples or a success signal are absent, offer to draft them for
   user review before creating a seed or selecting an optimization path.
2. If a scored task split exists, configure the current SkillOpt core training
   entry point and keep optimizer and target roles separate. The optimizer may
   use a different provider when the current guide supports it.
3. If the learning signal is the user's existing session history, create only a
   minimal valid seed `SKILL.md`, then use SkillOpt-Sleep against that exact
   target path.
4. Start with the runner's no-provider or mock path when available. Use a real
   backend only after the user opts in.
5. Evaluate the accepted artifact on held-out work, then present
   `best_skill.md` or the staged proposal before installing or adopting it.

If the user did not specify a target path, resolve the provider's native
project/plugin path from the current repository and runtime. Do not assume a
Claude path is valid for Codex or vice versa.

When the requested skill must work in both Claude and Codex, evaluate the same
seed or candidate separately in each target harness. Call it provider-neutral
only when both held-out gates pass; otherwise report the provider-specific
result and keep the targets separate.

## Claude Code handling

When the current runtime is Claude Code:

1. Read the current Claude integration before choosing between its native
   plugin command, bundled runner, or shared Python module.
2. Treat Claude transcript harvesting as local and read-only. Use the current
   documented project scope so unrelated `~/.claude` sessions are not mined.
3. Resolve one exact Claude target: the requested project `.claude/skills/...`
   skill, an existing plugin skill, or another explicit `SKILL.md` path. In a
   skill-only run, do not target `CLAUDE.md` memory unless the user explicitly
   asks for memory changes.
4. If the current integration exposes a handoff backend or command, offer it
   when the user wants the active Claude session to answer model prompts
   without a separate `claude -p` subprocess or additional API key. Answer
   each handoff prompt in a fresh context so the held-out gate is not
   contaminated.
5. Use the provider's native status, dry-run, run, and adopt surface when it is
   installed; otherwise use only shared runner commands confirmed by the
   current guide and `--help`.

For Codex, apply the same process to its current skill/runner integration and
archive scope. Keep the provider-specific adapter thin; the mode choice, gate,
staging, privacy, and reporting contract stay shared.

## Improve an existing skill

1. Resolve one exact `target-skill-path`; stop if multiple candidates are
   equally plausible.
2. Read the current skill and define the behavior to preserve and improve.
3. Check for usable provider session history. If it is absent, ask one question:
   "There are no relevant sessions. Should I draft 3–5 representative tasks
   with success criteria for your review?"
   Do not edit or select core/Sleep until the user answers.
4. Prefer SkillOpt-Sleep when the evidence is in provider session history.
   Restrict harvesting to the relevant provider and project.
5. Prefer core SkillOpt when the user supplies a reproducible task split and
   scorer.
6. Run a dry-run/mock pass first when the current runner supports it. Bound
   session/task selection and explain that these are not hard token, time, or
   cost budgets.
   Do not use a stateful mock `run` before a planned real run over the same
   archive: it can advance the harvest checkpoint. Use `dry-run` first, or
   export and review a task file for the real replay.
7. When improving only a skill, inspect the current SkillOpt config and use
   the documented settings that disable memory evolution, enable skill
   evolution, and keep the validation gate on. Do not assume config keys that
   the current guide or runner does not support.
8. Review baseline/candidate scores, gate result, exact diff, rejected edits,
   and evidence before any adoption.

For sensitive projects, harvest to a task file, inspect and redact it, set
`reviewed: true`, and replay only that reviewed file. Real backends may send
truncated transcript/task content to the selected provider; mock makes no
provider calls. Treat local evidence logs as sensitive.

## Provider handling

Identify the provider from the current runtime, not from a hardcoded default.
Keep these concepts separate:

- `source`: where history or task evidence is read from
- `backend`: which model/CLI performs mining, replay, judging, or reflection
- target harness: where the resulting skill will run
- transcript scope: which local provider/project history is eligible for
  harvesting

When the provider integration supports it, default to the active provider for
both source and backend:

- Claude runtime: Claude source/backend and Claude-native target path
- Codex runtime: Codex source/backend and Codex-native target path

The current SkillOpt guide may support cross-provider optimizer/target runs.
Use that only when the current docs and runner help confirm it.

## Adoption and reporting

Never silently overwrite a live skill or auto-adopt a candidate. Report:

- mode: new or improve
- target path and provider/harness
- SkillOpt source URL plus commit/version
- runner command/config actually used
- source/backend selection
- baseline and candidate scores, including the split used
- gate result and rejected edits
- exact staged diff and evidence path
- whether the artifact is only staged or explicitly adopted
- next action and any material privacy or interface mismatch

For existing skills, `adopt` is a separate explicit action and must preserve a
backup when the current integration provides one. For new skills, distinguish
the initial seed creation from later SkillOpt-generated changes.

## Common mistakes

- Using copied flags without reading the current SkillOpt repository and
  runner help.
- Confusing `source`, `backend`, and target harness.
- Calling a generated candidate an improvement before the held-out gate passes.
- Running a real backend on sensitive transcripts without review/redaction.
- Treating `max-sessions` or `max-tasks` as cost or token limits.
- Improving the wrong `SKILL.md` because the target path was inferred loosely.
- Creating a benchmark claim when no reproducible scorer or held-out split
  exists.
