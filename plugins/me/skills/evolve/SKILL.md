---
name: evolve
description: Use when asked to "evolve skill", "스킬 개선", "회고", or "analyze this session". Builds a transcript index, validates real-world scenarios with subagents, and proposes small patches to SKILL.md / AGENTS.md / CLAUDE.md with user approval.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Agent
---

# /me:evolve

Improve skills or local agent docs from transcript evidence. Keep changes small, evidence-bound, and approved by the
user before applying.

## Commands

```bash
/me:evolve
/me:evolve --session <transcript-session-id>
/me:evolve --recent [N]
/me:evolve --cwd <worktree-dir> --recent [N]
/me:evolve --cwd <worktree-dir> --skill <name> [--recent N]
/me:evolve --skill <name> [--recent N]
/me:evolve <skill> [<skill> ...]
/me:evolve <worktree-or-transcript-path>
/me:evolve --dry-run
```

`--session` expects the `.jsonl` transcript id, not the slash-command `ARGUMENTS` uuid. If the user did not explicitly
pass `--session`, do not invent one from `ARGUMENTS`.

Plain skill arguments are slash-command shorthand. For example, `/me:evolve handoff pickup` means run separate
`--skill handoff` and `--skill pickup` indexes; do not pass the raw positional list to `build-index.ts`.

Plain directory or `.jsonl` path arguments are analysis targets. A directory means "use the latest transcript for that
cwd". If the argument mixes a path with natural-language intent, interpret the intent first; do not forward the whole
sentence to the indexer.

Use `--cwd <worktree-dir>` when the user wants recent or skill-focused analysis for another worktree. For `--recent`
and `--session` this changes transcript discovery and repo-owned skill mapping. For `--skill` it only changes
repo-owned edit-target mapping — session discovery still scans all projects regardless of `--cwd`.

### Argument mapping rules

The indexer's `parseArgs` rejects conflicting flags with exit code `2`. Translate user input so it never trips these:

- A skill name plus a recent window is `--skill <name> --recent N`, never `--recent N <name>`. A bare skill name
  after `--recent` is parsed as a transcript path and exits `2`.
- One `--skill <name>` per indexer run. For multiple skills, run the indexer once per skill and treat each index
  independently through Phase 0/1. Never pass two `--skill` flags or a positional skill list.
- A positional path/dir is standalone. It cannot combine with `--cwd`, `--session`, `--skill`, or `--recent`. To
  focus a skill inside a worktree, use `--cwd <dir> --skill <name>` instead of a path plus a flag.

## Guardrails

- Do not read full raw transcripts in the main agent. Use the index and narrow turn ranges only.
- Do not edit external plugin cache paths under `~/.claude/plugins/cache/`; append those proposals to
  `docs/superpowers/evolutions/YYYY-MM-DD-upstream-suggestions.md`.
- Do not create new skills.
- Do not apply patches, commit, or push without explicit user approval.
- Repo-owned `plugins/*/skills/<name>/SKILL.md` files are valid edit targets.
- Skill scripts are TypeScript for Bun. Do not add shell or Python alternatives.

## Phase 0: Build Index

1. Dirty trees may still run read-only index and proposal discovery. Do not commit, stash, revert, or clean user
   changes.
2. Run the indexer from the skill base directory:

```bash
bun "<Base directory>/scripts/build-index.ts" [<jsonl-path-or-worktree-dir> | --cwd <dir>] [--session <id> | --recent N | --skill <name>]
```

Do not forward `--dry-run` to the indexer. It is handled by the main agent.

Exit codes: `0` ok, `2` bad args, `14` transcript/project/session/skill not found.

If the indexer prints a `[evolve] warning: …` line to stderr (e.g. `0 tool_use and 0 skill injections`, or
`parsed to 0 turns`), the harness transcript line format may have changed and extraction is silently producing empty
results. Do not treat an empty index as "no signals" in that case — surface the warning to the user and stop, since the
`FMT.*` format constants in `build-index.ts` likely need updating against the current transcript format.

Stop early when the index has no friction signal. A `kind:"skill"` event is an anchor (which skill was
active), not a friction signal — "has signals" means having interrupt/error/repeat/user events, not just
skill anchors. Evaluate these conditions in order:

- Single session with empty `events[]`: print `no improvement signals found in this session`.
- Recent/skill mode with empty `skills[]`: print `no invoked skills found in recent sessions`.
- All skills have signal `no events` (zero interrupt+error+repeat+user): print `no improvement signals found`.
- Otherwise: probe the skills with the strongest signal first.

## Index Notes

Single-session output has `summary` and `events[]`.

Recent and skill output has `mode:"recent"` and `skills[]`. The shape is flat and version-agnostic — the indexer
sums signals across every observed body of a skill name and does not compare against the current disk body. Each
skill includes:

- `signal`: one-line event counts (e.g. `3 interrupt, 3 error, 6 repeat, 10 user`), or `no events`
- `versions`: every skill version seen across sessions — context only, not used for matching
- `seen_in`: the `session_id`s where this skill was invoked
- `skill_path`: the cache SKILL.md path at invocation time (edit-target mapping is the proposal subagent's job)
- `events[]`: all friction signals for this skill name, summed across bodies, each tagged with `session`

Because the indexer no longer tracks current-body state, the proposal subagent reads the actual repo-owned
SKILL.md to judge whether a surfaced signal is already fixed before proposing a patch.

In `--recent` and `--skill`, each non-skill event (error/interrupt/repeat/user/agent) is attributed to the skill that
was active at its turn — the most recently invoked skill before that turn — not copied to every skill in the session.
Signals before the first skill invocation belong to no skill. So per-skill `signal` counts are scoped, but they are
turn-proximity heuristics: an event during one skill's run that was really caused by adjacent work can still be
mis-owned. Confirm ownership from event content before proposing, and prefer `kind:"skill"` events as anchors.
Each event carries `session` (its source `session_id`). The same failure recurring across distinct `session`
values is a strong signal; one concentrated in a single `session` is weak — likely steering noise from that run.

## Phase 1: Probe, Then Propose

### 1A. Scenario Probes

Run small `Agent` probes before asking for patches.

- Single-session index: 1-2 probes.
- `--recent` or `--skill`: 2-3 probes in parallel.
- Pick only lenses that have evidence in the index; do not manufacture no-signal work.

Useful lenses:

- correction chain
- cross-skill ownership
- noisy directives
- repeated exploration
- shared-session signals in `--recent`

Each probe may inspect only relevant `events[]` items and narrow
transcript turn ranges. It returns:

```json
{
  "scenario": "correction chain",
  "verdict": "proposal-worthy | diagnostic-only | no-signal",
  "event_indexes": [3],
  "target_owner": "plugins/me/skills/research/SKILL.md",
  "recommended_change": "one sentence",
  "why_this_is_real_world": "one sentence"
}
```

Synthesize probe results yourself. Keep only the best 1-2 `proposal-worthy` findings for proposal synthesis. Keep
`diagnostic-only` findings only for the final Probe summary.

### 1B. Proposal Subagent

Dispatch one proposal subagent. Include:

- the index JSON
- synthesized probe findings
- `docs/superpowers/specs/2026-05-27-evolve-skill-design.md`

The subagent must classify user events by relation to `event.prior`:

- `correction`
- `success`
- `directive`
- `question`
- `noise`

Target the file that owns the missing knowledge:

- that `SKILL.md` for trigger/body-rule failures
- a related `SKILL.md` for cross-skill ownership
- nearest `AGENTS.md` for repo navigation or file-location knowledge
- nearest `CLAUDE.md` for project-wide conventions

Required output is one JSON block:

```json
{
  "classifications": [
    {"event_index": 3, "label": "correction", "reason": "redirects prior grep"}
  ],
  "proposals": [
    {
      "id": "P1",
      "probe_scenario": "correction chain",
      "event_indexes": [3],
      "target_file": "<absolute path>",
      "is_external_cache": false,
      "change_kind": "edit",
      "patch": "<unified diff applicable with git apply>",
      "rationale": "1-2 sentences",
      "addresses_signal": "observed failure and why this patch would have prevented it"
    }
  ]
}
```

Reject broad rewrites or proposals without direct `event_indexes`.

## Phase 2: Approval And Apply

After parsing proposals:

1. Divert `is_external_cache:true` proposals to upstream suggestions; do not apply them.
2. If `--dry-run` was passed, show the plan only; do not ask for approval, apply patches, or commit.
3. Present one plan and ask once:

```text
Plan (N patches, one commit each):
P1  <target_file> - <rationale>
    probe: <probe_scenario>, events: <event_indexes>
    addresses: <addresses_signal>
    <full diff>

Apply and commit? [all / none / P1 P3]
```

1. Before applying or committing selected patches, require `git status --porcelain` to be empty except for
   upstream-suggestions files created by this run. If dirty, stop and ask the user to clean the tree.
1. Apply selected patches sequentially: `git apply` then one commit per patch.
1. If any patch fails, stop. Report the failed id, git error, and already-created commit SHAs.
1. Finalize with:
   - Probe summary: scenarios checked, proposal-worthy count, diagnostic-only/no-signal reasons
   - applied proposal ids with `probe_scenario` and `event_indexes`
   - commit SHAs
   - upstream suggestions path, if any
