---
name: evolve
description: Use when asked to "evolve skill", "스킬 개선", "회고", or "analyze this session". Reads the current session's transcript jsonl, extracts user corrections / verbose exploration / success patterns, and proposes patches to SKILL.md / AGENTS.md / CLAUDE.md one at a time with explicit user approval and individual commits.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Agent
---

# /me:evolve — Transcript-driven skill & doc evolution

Extract improvement signals from a session transcript and propose patches to SKILL.md / AGENTS.md / CLAUDE.md. One proposal at a time → user approval → Edit → individual commit.

## When to run

Only when the user invokes it explicitly. No automatic triggers.

```
/me:evolve                          analyze the current session
/me:evolve --session <id>           analyze a specific session by transcript session id
/me:evolve --recent                 analyze the most recent 10 sessions (multi-session review)
/me:evolve --recent <N>             analyze the most recent N sessions
/me:evolve --dry-run                show proposals only, don't apply
```

**`<id>` is a transcript session id** (the `.jsonl` filename under `~/.claude/projects/<project>/`), NOT the `ARGUMENTS` uuid that Claude Code injects when a slash command is invoked with a positional argument. If the user types `/me:evolve` with no explicit `--session` flag, do not pass `--session` to `build-index.ts` even if an `ARGUMENTS:` uuid appears in the prompt — let auto-detection run. Only forward `--session <id>` when the user explicitly provides a transcript session id.

## What this skill does NOT do

- Main agent never reads the raw transcript directly (avoid context blowup).
- Never modify external plugin cache (`~/.claude/plugins/cache/`) — it is read-only and gets overwritten on plugin updates. Accumulate those as upstream suggestions instead. If the user points you at the plugin's source repo (the path varies per user) and asks you to fix it there, redirect the edit to that source repo and commit there; the cache itself stays untouched.
- Never create new skills (that's `writing-skills` territory).
- Never auto-commit or auto-push (user must approve each proposal).
- SKILL.md files inside this repo's own `plugins/` ARE valid edit targets. "External cache" specifically means `~/.claude/plugins/cache/` only.

## Phase 0 — Build the index

The main agent does two things in Phase 0:

> **Language rule**: All skill scripts are written in TypeScript (Bun runtime). Do not propose shell/Python alternatives — applies to planning, review-agent suggestions, and implementation subagent instructions.

1. **Dirty-tree guard** — `git status --porcelain` must be empty. If dirty, print "commit or stash first, then re-run" and exit.

2. **Build the index** — `build-index.ts` is read-only: auto-detects the transcript, extracts signals, prints JSON.

Use the `Base directory for this skill: <path>` value injected at the top of this command prompt — do **not** rely on `${CLAUDE_PLUGIN_ROOT}` (it is not guaranteed to be set in the slash-command shell).

```bash
bun "<Base directory>/scripts/build-index.ts" [--session <id>]
```

Exit codes: `0`=ok, `2`=unknown flag (see §4 below — `--dry-run` must not be passed here), `14`=transcript or project dir not found.

Capture stdout JSON into a variable. **Do not show it to the user** — pass it only to the next-step subagent.

If `events` is empty, print "no improvement signals found in this session" and exit.

### --recent mode (multi-session review)

When `--recent [N]` is passed (default N=10), the indexer aggregates the most recent N sessions instead of one, emitting a **multi-session index** (`mode: "recent"`). The output is keyed on `skills[]`:

- Each skill entry: `name`, `skill_path` (current on-disk SKILL.md), `stale`, `dropped`, `seen_in` (sessions it appeared in), `events`.
- **Stale detection**: the indexer compares the hash of the *SKILL.md body as injected at invocation time* (preserved in the transcript) against the *current on-disk body*. If they differ (or the disk file is gone), the skill is `stale:true` → `dropped:true` → `events` is emptied. This avoids re-proposing changes to a skill that has already evolved since the session. It is decided by **body content hash, not the version number**, so "version bumped but body unchanged" is NOT stale.
- The skill identifier is the last directory name of the Base directory (e.g. `qa`) and may lack the slash-command prefix (`me:`).

`--recent` cannot be combined with `--session` (the indexer exits 2). `--dry-run` is still consumed by the main agent only and never forwarded to the indexer.

## Phase 1 — Subagent analysis (Agent)

Dispatch one subagent (`general-purpose`). The indexer hands user utterances over raw, so **classification is the subagent's job**.

> **Forbidden**: Do not add rule-based classification (regex, keyword matching) to `build-index.ts`. That pattern was abandoned because of false positives from words that happened to appear in normal prose. Classification must be done by the LLM.

The prompt must include all of:

1. Spec path: `docs/superpowers/specs/2026-05-27-evolve-skill-design.md`
2. The full index JSON from Phase 0 (`summary` + `events`). Read `summary.headline` (one-line state) and `summary.clusters` (same-kind events within ≤30 turns, ≥3 occurrences) first to spot dense regions, then walk `events[]` for causal-chain analysis. Clusters are a simple heuristic — skip meaningless ones.
   - **Multi-session (`mode:"recent"`)**: the index is a `skills[]` array. Analyze each skill's `events[]` per skill. A `dropped:true` (stale) skill already has its events emptied by the indexer, so it is never a proposal target — as a safety net, if you ever see `stale:true`, do not produce a proposal for that skill. Use each event's `session` field to identify which session the evidence came from, and cite the session when quoting evidence. `skill_path` is the proposal target candidate.
3. **Classification task for `kind: "user"` events** — label each one with exactly one of (refer by array index, e.g. `events[12]`):
   - **correction**: redirects/corrects the immediately preceding assistant action
   - **success**: positive feedback on the preceding assistant action
   - **directive**: a new instruction (not a correction or praise)
   - **question**: a question
   - **noise**: meta-chat, no analytical value

   Criterion is *the relation to the preceding assistant action (`event.prior`)*, not the words themselves. E.g. "stop and report" used as a directive verb is noise; "stop, that's wrong" reacting to a tool call is a correction.

4. Target-file selection — pick by *what kind of knowledge is missing*, not by signal pattern:

   - **that SKILL.md** — skill triggers, body rules, Red Flags. Use when a skill should have run but didn't, or ran but violated its own contract.
   - **nearest AGENTS.md** — repo navigation, file locations, "where to look" knowledge. Use when the agent searched/read repeatedly before finding something.
   - **nearest CLAUDE.md** — project conventions and rules that govern *all* work in this tree.

   **"Nearest" resolution**: "that SKILL.md" = inferred from `events[]` items with `kind:"skill"` or tool calls in `prior`. "Nearest AGENTS.md/CLAUDE.md" = walk up from that SKILL.md's directory; first hit wins (fallback to repo-root CLAUDE.md). If no skill can be inferred, default to repo-root CLAUDE.md.

5. Output schema — one JSON block only, no other text. `event_index` is the integer position in the index's `events[]` array:

   ```json
   {
     "classifications": [
       {"event_index": 3, "label": "correction", "reason": "redirects the prior grep"},
       {"event_index": 7, "label": "noise", "reason": "meta-chat"}
     ],
     "proposals": [
       {
         "id": "P1",
         "event_indexes": [3],
         "target_file": "<absolute path>",
         "is_external_cache": false,
         "change_kind": "edit",
         "patch": "<unified diff applicable with `git apply`>",
         "rationale": "1-2 sentences"
       }
     ]
   }
   ```

6. Instruction: "Read the events array first and notice that adjacent events near the same turn form causal chains. Only when needed, use `Bash` to extract just the relevant turn range from the jsonl. Never read the main transcript in full. Return only the result JSON."

## Phase 2 — Apply loop

After parsing the subagent's returned JSON:

> Do not save Phase 1 results or a session retrospective to a separate report file. Unpack the JSON inline at the console and walk it with the user one proposal at a time. The only byproduct file is `upstream-suggestions.md` (and only when an external-cache proposal occurs).

1. Proposals with `is_external_cache: true` are diverted to `docs/superpowers/evolutions/YYYY-MM-DD-upstream-suggestions.md` (append; create if missing). Do not attempt Edit on them.
2. Present the remaining proposals to the user, starting at #1:

   ```
   P1. <target_file>
     Evidence: <event_indexes> (snippet)
     Rationale: <rationale>

     [patch diff]

     Apply? [y / n / skip / edit]
   ```

3. Based on the response:
   - **y**: `git apply <patch-file>` → `git commit -m "evolve: <subject>"` (one patch = one commit; revert with `git revert <sha>`). If the target is under `~/.claude/plugins/cache/`, refuse to apply and divert to upstream-suggestions.
   - **edit**: let the user edit the patch, then proceed as `y`.
   - **skip / n**: move on to the next proposal.

4. If `--dry-run` is passed, skip Phase 2 entirely and just print the proposal list. `--dry-run` is consumed by the main agent only — never forward it to `build-index.ts` (the script will exit 2 on unknown flags).

5. Finalize: print the list of applied commit SHAs and the upstream-suggestions path (if any).

## Safety

- `git status --porcelain` must be empty at start (refuse on dirty tree).
- External-cache paths (`~/.claude/plugins/cache/`) are refused → diverted to upstream-suggestions.
- Always show the diff to the user before applying any patch.
- Each change gets its own commit → revert one with `git revert <sha>`.
