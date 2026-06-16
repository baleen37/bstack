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
/me:evolve --skill <name> [--recent N]
/me:evolve --dry-run
```

`--session` expects the `.jsonl` transcript id, not the slash-command `ARGUMENTS` uuid. If the user did not explicitly
pass `--session`, do not invent one from `ARGUMENTS`.

## Guardrails

- Do not read full raw transcripts in the main agent. Use the index and narrow turn ranges only.
- Do not edit external plugin cache paths under `~/.claude/plugins/cache/`; append those proposals to
  `docs/superpowers/evolutions/YYYY-MM-DD-upstream-suggestions.md`.
- Do not create new skills.
- Do not auto-commit, auto-push, or apply patches without user approval.
- Repo-owned `plugins/*/skills/<name>/SKILL.md` files are valid edit targets.
- Skill scripts are TypeScript for Bun. Do not add shell or Python alternatives.

## Phase 0: Build Index

1. Refuse dirty trees: if `git status --porcelain` is non-empty, print `commit or stash first, then re-run` and stop.
2. Run the indexer from the skill base directory:

```bash
bun "<Base directory>/scripts/build-index.ts" [--session <id> | --recent N | --skill <name>]
```

Do not forward `--dry-run` to the indexer. It is handled by the main agent.

Exit codes: `0` ok, `2` bad args, `14` transcript/project/session/skill not found.

Stop early when the index has no current evidence:

- Single session with empty `events[]`: print `no improvement signals found in this session`.
- Recent mode with empty `skills[]`: print `no invoked skills found in recent sessions`.
- All candidate skills dropped: report `drop_reason`, `skill_path`, and `observed_bodies[].versions`; do not run proposal
  subagents.
- No current skill has events: print `no improvement signals found in current skill bodies`.

## Index Notes

Single-session output has `summary` and `events[]`.

Recent and skill output has `mode:"recent"` and `skills[]`. Each skill includes:

- `signal`: one-line event counts, or `dropped (<drop_reason>)`
- `drop_reason`: `stale` or `missing_current_body`
- `observed_bodies`: diagnostic body hashes and versions
- `repo_path`: editable repo-owned source when available
- `events[]`: only events matching the current skill body

Use `summary.headline` as the freshness check. Treat `observed_bodies` as diagnostics, not proposal evidence.

In `--recent`, non-skill events are copied to every skill invoked in that session. If several skills share the same
`signal` and `seen_in`, do not treat those counts as per-skill evidence. Inspect event content and prefer `kind:"skill"`
events before assigning ownership.

## Phase 1: Probe, Then Propose

### 1A. Scenario Probes

Run small `Agent` probes before asking for patches.

- Single-session index: 1-2 probes.
- `--recent` or `--skill`: 2-3 probes in parallel.
- Pick only lenses that have evidence in the index; do not manufacture no-signal work.

Useful lenses:

- correction chain
- cross-skill ownership
- stale/drop diagnostics
- noisy directives
- repeated exploration
- shared-session signals in `--recent`

Each probe may inspect only relevant `events[]` items and narrow transcript turn ranges. It returns:

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

Reject broad rewrites, proposals without direct `event_indexes`, or patches based only on dropped/stale bodies.

## Phase 2: Approval And Apply

After parsing proposals:

1. Divert `is_external_cache:true` proposals to upstream suggestions; do not apply them.
2. Present one plan and ask once:

```text
Plan (N patches, one commit each):
P1  <target_file> - <rationale>
    probe: <probe_scenario>, events: <event_indexes>
    addresses: <addresses_signal>
    <full diff>

Apply? [all / none / P1 P3]
```

1. Apply selected patches sequentially: `git apply` then one commit per patch.
1. If any patch fails, stop. Report the failed id, git error, and already-created commit SHAs.
1. If `--dry-run` was passed, show the plan only and stop.
1. Finalize with:
   - Probe summary: scenarios checked, proposal-worthy count, diagnostic-only/no-signal reasons
   - applied proposal ids with `probe_scenario` and `event_indexes`
   - commit SHAs
   - upstream suggestions path, if any
