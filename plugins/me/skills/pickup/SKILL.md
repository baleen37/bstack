---
name: pickup
description: Use when asked to "pickup", "픽업", "이어서", "이전 세션 이어서", "resume where I left off", or "restore context" — locates the handoff file, surfaces the Resume Prompt verbatim, and warns on worktree/branch mismatch before continuing. Pair with /handoff.
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# /pickup: Resume from a handoff file

Read a handoff written by `/handoff` and continue the previous session's work. Pair with `/handoff`.

The hard part is **not** finding the directory — Claude can do that. The hard part is **not silently picking the wrong file, not summarizing the Resume Prompt away, and not papering over a worktree/branch mismatch with inference**. This skill exists to enforce that discipline.

## What `/pickup` does

- Lists candidates from `~/.claude/handoff/`
- If multiple candidates exist, **asks the user to pick** (never auto-matches by topic/branch)
- Reads the chosen file
- Compares its `worktree` and `branch` to the current ones, reports any mismatch, and **stops to ask** before proceeding when they differ
- Quotes the Resume Prompt **verbatim** in a code block — never paraphrased
- Surfaces Failed Approaches and Open Questions
- Cross-checks the handoff against `git log` since the handoff was written, and reports any work that may already be done
- Then continues using the recovered context

## What `/pickup` does NOT do

- Does not write or modify files
- Does not auto-checkout branches or change worktrees
- Does not pick a file by topic match, branch name, or recency alone when multiple files exist
- Does not summarize, paraphrase, or "improve" the Resume Prompt
- Does not search project-local directories — only `~/.claude/handoff/`
- Does not silently skip Failed Approaches even when they look outdated

## Steps

1. **List candidates** (newest first):
   ```bash
   ls -t ~/.claude/handoff/*.md 2>/dev/null | head -10
   ```
   If empty/missing → tell the user there is nothing to pick up. Stop. Do not fabricate context from `git log`.

2. **Choose a file** — strict rules:
   - **0 candidates** → stop (above).
   - **1 candidate** → use it.
   - **2+ candidates** → use AskUserQuestion (load via ToolSearch if it's a deferred tool: `ToolSearch select:AskUserQuestion`; if unavailable, ask inline). Show top 5 with `<filename> — <first-line title>`. **Never auto-pick** by branch name match, topic match, or "most recent." The user picks.
   - If the user's request named a topic, you may **suggest** a default in the question, but the user still confirms.

3. **Read the file** with the Read tool.

4. **Environment compare** — run in parallel:
   ```bash
   git branch --show-current
   git rev-parse --short HEAD
   pwd
   ```
   Compare against the file's frontmatter `worktree`, `branch`, `commit`.

5. **Mismatch handling** — if `worktree` or `branch` differs:
   - Report the mismatch on its own line: `⚠ MISMATCH: handoff was on <branch> in <worktree>, current is <branch> in <pwd>`
   - **Stop and ask neutrally.** Use AskUserQuestion (load it via ToolSearch first if it appears as a deferred tool — `ToolSearch select:AskUserQuestion`; if it can't be loaded, ask inline as a single plain question). Question text must offer the three options and **nothing else** — no editorial like "the topic matches so we're probably fine here." Suggested phrasing:
     > "Handoff records a different worktree/branch. Continue here anyway, switch yourself, or abort?"
   - Do not proceed without an explicit answer. Do not infer based on topic/branch-name similarity. Do not nudge the user toward "continue" by appending your own reasoning to the question.

6. **Surface the Resume Prompt verbatim** — copy the entire `## Resume Prompt` section into a code block. No paraphrasing. No "in summary." Quote it.

7. **Surface Failed Approaches verbatim** — if the file has a `## Failed Approaches` section, output it as a bulleted list before doing any work. These exist to stop you from repeating the previous session's mistakes.

8. **Drift check** — run `git log --oneline <handoff-commit>..HEAD` (using the frontmatter commit). If there are commits since the handoff, list them and warn: "the handoff predates these commits — some Next Steps may already be done." Do not assume which.

9. **Continue work** — treat the verbatim Resume Prompt as the user's instruction. Honor Open Questions (ask the user before deciding them yourself).

## Output Shape

```
Picked up: <absolute path>
Recorded: <branch> @ <commit> in <worktree>
Current:  <branch> @ <commit> in <pwd>
[⚠ MISMATCH line if any]

Resume Prompt:
> <verbatim quote of the entire Resume Prompt section>

Failed Approaches (do not repeat):
- <verbatim bullet>
- <verbatim bullet>

Open Questions:
- <verbatim bullet>

Drift since handoff (<N> commits):
- <sha> <subject>
- ...

Proceeding with the Resume Prompt above.
```

Omit any section the file does not contain. Do not fill in "N/A".

## Quick Reference

| Situation | Action |
|---|---|
| 0 files | Stop. Tell the user. Don't guess from `git log`. |
| 1 file | Use it. Still do mismatch + drift checks. |
| 2+ files | AskUserQuestion. Never auto-pick. |
| Worktree/branch matches | Continue. |
| Worktree/branch differs | Report + AskUserQuestion before continuing. |
| Commits since handoff | List them; warn that some Next Steps may already be done. |
| Resume Prompt feels redundant | Quote it anyway, verbatim. |
| Failed Approaches look outdated | Quote them anyway. |

## Common Mistakes

- **Auto-picking the file whose name matches the current branch.** The branch matched by accident before; now you've loaded the wrong session's context. Always ask when 2+ exist.
- **Paraphrasing the Resume Prompt** ("the user was working on X, got to Y, wants Z next"). The verbatim text encodes the previous session's exact framing — paraphrasing strips nuance the next steps depend on. Quote it.
- **Skipping Failed Approaches** because they "look obvious" or "the situation has changed." They were recorded specifically to stop a future agent from repeating them. Quote them.
- **Inferring through a worktree mismatch** ("different repo path but same topic, must be the same work"). That's exactly the inference that loads stale context. Stop and ask.
- **Nudging the user toward "continue" inside the mismatch question.** Adding "the topic matches so we're probably fine here" to the question text is a back-door auto-pick. Ask the three options and stop — no commentary inside the question.
- **Treating drift as automatic completion** ("there's a commit titled `feat: add X`, so Next Step #1 is done"). Commit titles can be misleading and partial. Report drift; let the user decide.
- **Reading multiple handoffs and merging.** Pick exactly one file per `/pickup` invocation.

## Red Flags — STOP

- About to pick a file based on branch/topic match without asking → **stop**, AskUserQuestion.
- About to summarize the Resume Prompt instead of quoting it → **stop**, quote it verbatim.
- About to proceed despite worktree/branch mismatch because "topic matches" → **stop**, AskUserQuestion.
- About to add "but the topic matches" to the mismatch question → **stop**, ask the three options neutrally with no editorial.
- About to skip Failed Approaches because the situation looks different now → **stop**, quote them.
- About to declare Next Steps already done from `git log` alone → **stop**, report drift; user decides.
- About to write a new handoff inside `/pickup` → that's `/handoff`, wrong skill.
