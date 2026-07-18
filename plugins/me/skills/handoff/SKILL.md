---
name: handoff
description: >-
  Use when asked to "handoff", "인수인계", "write a handoff", or before ending
  a session to preserve context for the next session.
allowed-tools:
  - Bash
  - Read
  - Write
---

# /handoff: Write a session handoff file

Save the current session's context to
`~/.local/share/bstack/handoff/YYYY-MM-DD-HHmm-<topic>.md` as a structured
markdown file. Runs only when the user explicitly asks for it.

The handoff directory is `${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff`
— honor `$XDG_DATA_HOME` when set. Written below as `~/.local/share/bstack/handoff/`.

There is no resume logic in this skill. The next session picks up context by
pasting the file path or contents directly and follows the Resume Protocol.

## Arguments

If the user passes text after `/handoff` (e.g. `/handoff now we need to join and
index this into search`), treat it as an **explicit next-step instruction** and
make it the `First action` at the top of `## Next Steps`, before any steps
inferred from the conversation. Include it verbatim and label it: `(from user
at handoff time)`.

## What `/handoff` does

- Extracts the task, completed work, current state, next steps, blockers, and
  stable context pointers from the current conversation
- Collects a git/environment snapshot
- Writes a file under `~/.local/share/bstack/handoff/`
- Prints the saved path

## What `/handoff` does NOT do

- Does not start a new session or read prior handoffs (write-only)
- Does not dump the full conversation history
- Does not save to the project directory (global `~/.local/share/bstack/handoff/` only)
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

   ```text
   ~/.local/share/bstack/handoff/YYYY-MM-DD-HHmm-<topic>.md
   ```

   e.g. `~/.local/share/bstack/handoff/2026-04-22-1430-add-handoff-skill.md`

4. **Ensure directory** — `mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff"`

5. **Write the file** using the template below. Always include `Task`,
   `Completed`, `Current State`, and `Next Steps`. Emit conditional sections
   only when they prevent a concrete resume error; never leave empty sections.
   - If this session started from a previous handoff file, add
     `continues: <that handoff's filename>` to the frontmatter so chained
     sessions stay traceable. Omit the key otherwise.

6. **Validate before printing** — re-read the written file and check:
   - No empty sections or placeholder text (`TODO`, `...`, `N/A`)
   - No secrets (tokens, credentials, connection strings)
   - Every referenced file path exists; every claim of done/passing state has a
     re-check command
   - `Task`, `Completed`, `Current State`, and `Next Steps` are present and do
     not mix completed, in-progress, and unstarted work

   Fix in place if any check fails.

7. **Print the absolute path** on a single line.

## Output Template

```markdown
---
date: YYYY-MM-DD HH:mm
worktree: <pwd>
branch: <git branch>
commit: <short sha>
topic: <kebab-case>
continues: <previous handoff filename — only if this session resumed from one>
---

# Handoff: <one-line title>

## Task
- Goal: <goal derived from the session>
- Scope: <in-scope work and explicit boundaries>
- Done when: <verifiable completion condition>

## Completed
- <concrete completed outcome>

## Current State
- In progress: <unfinished work currently underway>
- Workspace: `<worktree>` on `<branch>` at `<commit>`
- Workspace health: clean / dirty, including user-owned unrelated changes
- Last verified: `<command-or-check>` → <result>

## Next Steps
1. First action: <the exact action to resume safely, including any required preflight re-check>
2. <next action> → verify with `<check>` or Done when: <evidence>

## Blockers & Open Questions
- <unresolved decision, dependency, or unknown>

## Context
- Files: `path/a.ts`
- PR / issue / doc / run: <stable identifier or URL>

## Design Decisions
- Decision: <chosen approach> — Reason: <why it was chosen>

## Failed Approaches
- Tried: `<command-or-approach>` — Failed because: <exact useful reason>

## Gotchas
- <forward-looking temporary constraint the next session must preserve>
```

`Blockers & Open Questions`, `Context`, `Design Decisions`, `Failed
Approaches`, and `Gotchas` are conditional. Omit them unless their content
prevents a concrete resume error.

## Resume Protocol

The receiving session must:

1. Compare the recorded worktree, branch, and commit with the current environment.
2. Re-run `Last verified` before trusting state claims.
3. Report any material drift or mismatch instead of inferring through it.
4. Only then start the recorded `First action`.

## Content Rules

- **Bullets over prose.** One bullet, one line.
- **Only what was actually discussed or decided.** No speculative "possible next steps."
- **Capture resumable state, not logs.** The next session should know where to
  resume, what was last verified, and what to check first.
- **Prefer stable pointers.** Use paths, PRs, issues, docs, commands, artifact
  names, and source links over copied output.
- **Next Steps should be verifiable.** Prefer "do X → verify with Y" when the check matters.
- **First action is singular.** Put the exact preflight or work action that the
  receiving session must perform first at the beginning of `Next Steps`.
- **State claims need a re-check path.** Pair every "merged / tests pass / deployed"
  claim with the exact command to re-verify it. The next session cannot tell a
  verified claim from an assumed one — an unverifiable claim gets treated as
  ground truth and poisons everything built on it.
- **No secrets or noisy logs.** Summarize evidence; do not paste tokens, credentials, stack dumps, or full command output.
- **Failed Approaches matter** — they stop the next session from repeating mistakes.
  One line each: "tried → why it failed." Keep the exact error or command; don't
  blur it into "it didn't work."
- **Gotchas ≠ Failed Approaches.** Failed Approaches record past attempts; Gotchas
  record forward constraints the next session must respect.
- **Blockers & Open Questions** = unresolved at session end. Anything already
  decided goes under Design Decisions.
- **Temporary context is not a permanent rule.** When a lasting repository or
  user instruction already exists in `AGENTS.md` or `CLAUDE.md`, point to that
  file instead of copying the rule into the handoff. Do not modify the
  instruction file during handoff.

## Red Flags — STOP

- Dumping the whole conversation → stop; extract only the essentials.
- Writing "maybe next we could..." speculation → delete it; record only what was actually discussed.
- Filling empty sections with "N/A" → delete the section instead.
- Writing "tests pass" / "deployed" with no re-check command → add the exact verification command or soften the claim.
- Tempted to add resume/read logic → this skill is write-only.
