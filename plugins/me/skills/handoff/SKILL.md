---
name: handoff
description: Compact this session into a state handover another agent can verify and resume from. Use when the work is moving to a new session, a different harness, another directory, or someone else.
argument-hint: "What will the next session focus on?"
disable-model-invocation: true
---

# Handoff

Write a handover the next session can **verify and resume from** — not a
retrospective of this one.

**Announce at start:** "I'm using the handoff skill to write the handover."

**Save to:** `~/.claude/handoff/YYYY-MM-DD-HHmm-<topic>.md`

- `<topic>` is a 2-4 word kebab-case summary you derive from the work
- Local time, so the filename is readable without timezone arithmetic
- Create the directory if it does not exist
- Report the path when you're done

This is a global directory, not project-local, and its output is not tracked by
git.

## When a handoff is the right move

A handoff is narrow. It is worth its cost only when something is **travelling**:

- a different harness (Claude Code → Codex),
- a different directory or repo,
- another person,
- or a side task you found mid-phase and want to fork without derailing this
  one.

If nothing travels, you want `/clear` or `/compact` instead — see
[ask/PHASE-BOUNDARIES.md](../ask/PHASE-BOUNDARIES.md) for the ordered tree.
Writing a handoff to end a session that could simply continue pays the
summary's lossiness for nothing.

## Collect the environment first

Run these in parallel before writing anything, so the state you record is
observed rather than remembered:

```bash
git status --short
git diff --stat
git log -5 --oneline
git branch --show-current
pwd
```

## Output

Front matter, then the required core. Add a conditional section only when it
has real content.

```markdown
---
date: YYYY-MM-DD HH:mm
worktree: /path/to/worktree
branch: <branch>
commit: <sha>
topic: <kebab-case>
---

# Handoff: <one short line>

## Task
- Goal: <what this work is for>
- Scope: <what is in, concretely>
- Done when: <the observable condition>

## Completed
- <what this session actually finished>

## Current State
- <where the work stands right now>
- Worktree: `<path>`, branch: `<branch>`, commit: `<sha>`
- Last verified: `<command>` → <result>

## Next Steps
1. <the first action, stated as an action> → verify: <how you'd know>
2. ...

## Blockers & Open Questions
- <unconfirmed facts, decisions waiting on the user, external blockers>

## Context
- <stable pointers: files, PRs, issues, docs, command output>
```

**Conditional sections** — include only to prevent a real resume error:

| Section | Holds |
| --- | --- |
| `Design Decisions` | The decision and why |
| `Failed Approaches` | What was tried, its exact failure, why not to repeat it |
| `Gotchas` | A temporary constraint the next session must respect |
| `Explicit User Instruction` | A next action the user named when invoking this |

Don't copy permanent preferences or repo rules into a handoff. If a rule
already lives in `CLAUDE.md` or `AGENTS.md`, reference the path.

## Resume protocol

There is no separate "resume prompt" section, because `Current State` and
`Next Steps` already are one. A fresh agent reading this file should:

1. Check the recorded worktree, branch, and commit against its environment.
2. Re-run the `Last verified` command, or confirm the state hasn't moved.
3. On a mismatch, report the difference rather than proceeding on a guess.
4. Start from the first action in `Next Steps`.

Write those four steps' inputs well and the file needs no resume instructions
of its own.

## Content rules

- Make the current state understandable before any chronology.
- Don't mix done, in progress, and not started.
- Separate confirmed facts from hypotheses.
- Prefer re-checkable pointers: paths, commits, PRs, issues, commands.
- Never record secrets, full logs, stack traces, or conversation dumps.
- No `TODO`, `N/A`, `...`, or empty sections. Cut the section instead.
- Don't duplicate what another artifact already holds — a spec, plan, ADR,
  issue, commit, or diff. Reference it by path or URL.

## Suggested skills

Close with the skills the next session should reach for, so it doesn't
rediscover the route. `/me:ask` is the map if you're unsure what to name.

## Red Flags

| Rationalisation | What it actually means |
| --- | --- |
| "I'll dump the conversation so nothing is lost" | Noise buries the state. The next agent reads the file to act, not to relive. |
| "I'll list possible next steps" | Speculation reads as decided. Only what was actually discussed or decided. |
| "The section is empty but the template has it" | Cut it. An empty heading tells the next session nothing. |
| "I'll note the user's preferences here too" | If it's permanent, it belongs in `CLAUDE.md`; reference the path. |
| "Session's ending, so I should write a handoff" | Ending isn't travelling. Check the phase-boundary tree first. |
