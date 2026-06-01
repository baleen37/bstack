---
name: handoff
description: Use when asked to "handoff", "인수인계", "write a handoff", or before ending a session to preserve context for the next session. Writes a structured markdown file to ~/.claude/handoff/ capturing goals, decisions, open questions, and failed approaches so the next session can resume without losing context.
allowed-tools:
  - Bash
  - Read
  - Write
---

# /handoff: Write a session handoff file

Save the current session's context to `~/.claude/handoff/YYYY-MM-DD-HHmm-<topic>.md` as a structured markdown file. Runs only when the user explicitly asks for it.

There is no resume logic in this skill. The next session picks up context either by invoking `/pickup` (which reads the most recent file from `~/.claude/handoff/`) or by pasting the file path or contents directly — Claude reads the frontmatter and the Resume Prompt section and takes it from there.

## Arguments

If the user passes text after `/handoff` (e.g. `/handoff now we need to join and index this into search`), treat it as an **explicit next-step instruction** and include it verbatim at the top of the `## Next Steps` section — before any steps inferred from the conversation. Label it: `(from user at handoff time)`.

## What `/handoff` does

- Extracts goal, decisions, next steps, and blockers from the current conversation
- Collects a git/environment snapshot
- Writes a file under `~/.claude/handoff/`
- Prints the saved path

## What `/handoff` does NOT do

- Does not start a new session or read prior handoffs (write-only)
- Does not dump the full conversation history
- Does not save to the project directory (global `~/.claude/handoff/` only)
- Does not register any automatic trigger (no SessionEnd hook, etc.)

## Steps

1. **Collect environment snapshot** — run in parallel:
   - `git status --short`
   - `git diff --stat`
   - `git log -5 --oneline`
   - `git branch --show-current`
   - `git rev-parse --short HEAD`
   - `pwd`

2. **Infer topic** — summarize the session's main work as a 2–4 word kebab-case slug (e.g. `refactor-auth-middleware`, `add-handoff-skill`).

3. **Build filename** — local time:
   ```
   ~/.claude/handoff/YYYY-MM-DD-HHmm-<topic>.md
   ```
   e.g. `~/.claude/handoff/2026-04-22-1430-add-handoff-skill.md`

4. **Ensure directory** — `mkdir -p ~/.claude/handoff`

5. **Write the file** using the template below. **Omit any section that has no real content.** Do not leave empty sections.

6. **Print the absolute path** on a single line.

## Output Template

```markdown
---
date: YYYY-MM-DD HH:mm
worktree: <pwd>
branch: <git branch>
commit: <short sha>
topic: <kebab-case>
---

# Handoff: <one-line title>

## Resume Prompt
> A single paragraph the user can paste verbatim into the next session. "I was working on X and got as far as Y. Pick it up from Z."

## Goal & Current State
- Goal: ...
- Current state: ...

## Next Steps
1. ...
2. ...

## Open Questions
- ... (pending decisions / blockers)

## Design Decisions
- Decision: ... — Reason: ...

## Failed Approaches
- Tried: ... — Why it failed: ...

## Recent Changes
- Modified: `path/a.ts`
- Commits: `abc1234 feat: ...`
- Uncommitted: <git status summary>

## Environment
- Worktree: `/path`
- Branch: `feature/xyz`
- PR/Issue: #123

## User Preferences
- ...
```

## Content Rules

- **Bullets over prose.** One bullet, one line.
- **Only what was actually discussed or decided.** No speculative "possible next steps."
- **Failed Approaches matter** — they stop the next session from repeating mistakes. One line each: "tried → why it failed."
- **Open Questions** = unresolved at session end. Anything already decided goes under Design Decisions.
- **Resume Prompt** must stand alone. Include file paths, ticket numbers, and enough context to be understood without reading the rest of the file.

## Red Flags — STOP

- Dumping the whole conversation → stop; extract only the essentials.
- Writing "maybe next we could..." speculation → delete it; record only what was actually discussed.
- Filling empty sections with "N/A" → delete the section instead.
- Tempted to add resume/read logic → this skill is write-only.
