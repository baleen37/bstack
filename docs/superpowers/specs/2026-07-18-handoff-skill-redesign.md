# Handoff Skill Redesign

## Purpose

Refocus `me:handoff` on transferring actionable task state to another session.
The handoff should answer, in order: what the task is, what is already done,
where work currently stands, and exactly how to continue.

## Success Criteria

- A new session can identify the first action without reconstructing the conversation.
- Completed work is separate from current and remaining work.
- Claims such as tests passing, a PR merging, or a deployment succeeding include a re-check path.
- The document preserves important decisions and failed attempts without becoming a transcript.
- Empty or irrelevant sections are omitted.

## Output Structure

The generated handoff uses six core section slots. `Task` and `Current State`
are always present; omit any other slot that has no real content:

1. **Task**
   - Goal
   - Scope
   - Definition of done
2. **Completed**
   - Concrete outcomes already achieved
3. **Current State**
   - Work in progress
   - Worktree, branch, and commit
   - Last verification command and result
4. **Next Steps**
   - One explicit first action
   - Remaining ordered actions, each paired with verification when relevant
5. **Blockers & Open Questions**
   - Unresolved decisions, dependencies, and unknowns
6. **Pointers**
   - Important files, PRs, issues, documents, runs, and other stable sources of truth

The following sections are conditional and appear only when they prevent lost
context or repeated work:

- Design Decisions
- Failed Approaches
- Gotchas
- Explicit next-step instructions supplied by the user at handoff time

## Resume Contract

The handoff is a portable checkpoint, not a conversation dump or a replacement
for native session resume. The receiving session should:

1. Confirm the recorded worktree, branch, and commit still match.
2. Run the recorded re-check before trusting state claims.
3. Report material drift or mismatch instead of silently inferring through it.
4. Start with the explicit first action.

A standalone resume paragraph may be generated from the structured fields, but
it must not introduce information absent from them. It is a convenience view,
not a second source of truth.

## Content Rules

- Prefer outcomes and stable pointers over chronological narration.
- Separate confirmed facts, unresolved questions, and user instructions.
- Record exact commands or errors only when they enable verification or prevent
  repeating a failed approach.
- Keep permanent repository rules in `AGENTS.md`, `CLAUDE.md`, or an equivalent
  persistent instruction file; reference that file rather than copying the rules
  into every handoff.
- Preserve user-owned and unrelated working-tree changes as explicit workspace
  context when they affect continuation.

## Non-Goals

- Reintroducing `pickup` or adding resume/read logic to the handoff skill
- Saving the full conversation or command log
- Adding incident-management roles, severity, communications cadence, or RCA
  fields to ordinary development handoffs
- Changing the in-progress XDG handoff storage migration

## Validation

Use baseline and revised-skill scenarios to compare generated handoffs for:

- explicit separation of completed, current, and remaining work;
- a single unambiguous first action;
- verification evidence for state claims;
- correct handling of dirty worktrees, blockers, failed attempts, and user-supplied next steps;
- omission of redundant, speculative, or empty sections.

The redesign passes when fresh agents can resume representative tasks from the
generated handoff without reading the original conversation and without treating
stale state as current.
