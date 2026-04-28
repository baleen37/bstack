---
name: ship
description: Use when the user asks to "ship", "launch", "release", "deploy", "출시", "런치", "배포", or wants help running a production launch — pre-launch checks, staged rollout, monitoring, rollback. Curates launch tasks based on change risk and walks through them one task at a time.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# /ship: Launch Task Runner

`/ship` is a stepwise launch helper. It curates launch tasks for the current change and walks through them one task at a time with the user.

`/ship` does NOT:
- run deploy commands
- merge PRs or push to remote
- replace `/qa` or `/e2e` (it consumes their evidence)
- bypass the gate when evidence is missing

## The phases

Always run these in order. Do not skip phases. Do not collapse phases.

```
SCOPE → GATE → CLASSIFY → PLAN → EXECUTE → WRAP
```

### 1. SCOPE

Gather evidence about the current change. Read, do not assume:

- `git status` and `git diff main...HEAD` (or current base branch)
- recent `/qa` or `/e2e` evidence in the conversation or repo
- the user's one-line description of the change

If you cannot read the diff, say so and stop. Do not proceed on user testimony alone. This rule is not waived by user permission, simulation/test context, "trust me it's small", or time pressure. The way to unblock is to provide diff text or fix tool access — not to skip SCOPE.

### 2. GATE

Block the launch if any of these are true. Do not proceed to CLASSIFY:

- no test or verification evidence at all
- the change touches money, auth, or data integrity AND has no `/qa` evidence
- rollback path is completely unknown AND the change is not trivially revertible
- the user is invoking `/ship` under sunk-cost or deadline pressure on a risky change

Sunk cost ("90% done"), deadline ("30 min left"), and authority ("the lead said to merge it") are NOT readiness signals. State this directly when refusing.

If gated, report:
- one sentence on why
- the smallest set of evidence needed to unblock
- stop. Do not create tasks.

### 3. CLASSIFY

Assign exactly one risk class to the change. Read `references/curation-rules.md` for criteria.

- **low** — docs, internal tools off by default, additive UI to <10 internal users
- **standard** — user-facing feature, API change, observable behavior change
- **risky** — payment/auth/data migration/permissions/billing, broad user impact, irreversible

State the class explicitly, in one word, with one sentence of evidence: "Class: standard — adds a new public endpoint exposed to all users."

If unclear between two classes, pick the higher one.

### 4. PLAN

Build the task list from `references/curation-rules.md` based on the class. Each class has a default task set. Add change-specific tasks if the diff reveals them (DB migration, new env var, new dependency).

Present the task list to the user as a numbered preview — task **titles only**, plus the playbook section reference where details live. Do NOT inline the playbook content (rollout thresholds, checklist items, rollback templates) at PLAN time. Long expanded previews invite "looks fine, just go" rubber-stamping. Keep the preview scannable. Ask: "Proceed with these N tasks? You can add, remove, or reorder."

Do NOT call TaskCreate yet. Wait for explicit user approval.

**Handling task removal requests in PLAN edit:**

The user may push back on the task list ("skip canary, drop 1-week watch"). Do not bulk-accept and do not bulk-refuse. Triage per item:

1. Does removing this task effectively *downgrade the class* (e.g., risky → standard by deleting feature flag + canary)? If yes, refuse — they should re-classify, not edit.
2. Can the *purpose* be preserved by a different mechanism (e.g., small population → "team window 72h" instead of "5% canary")? If yes, propose the variant.
3. Is the task purely tracking metadata (e.g., "feature flag cleanup task") that can be absorbed into another task without losing the underlying rule (owner + expiration date)? If yes, absorb and confirm.
4. Is the user's argument empirical (e.g., "5% of 50/day = 2.5 users, statistically meaningless")? Engage with the argument, do not refuse mechanically. The goal is the underlying intent (blast-radius limiting, observability, reversibility), not the literal task wording.

State the per-item decision explicitly when responding.

### 5. EXECUTE

After approval, call TaskCreate once with all tasks set to `pending`.

Then loop:
1. Pick the first `pending` task. Set it to `in_progress` via TaskUpdate.
2. Show the task content and what evidence/action satisfies it.
3. Wait for the user to confirm done OR provide evidence OR say "skip with reason".
4. Mark `completed` (or `cancelled` with reason). Move to next.
5. If the user reports a blocker, stop the loop and report. Do not auto-mark remaining tasks.

Only one task is `in_progress` at a time. Even when the user batch-confirms ("tasks 1, 2, 3 done"), call TaskUpdate per task, not all at once. The pacing IS the discipline.

**Handling phase backtrack (mid-EXECUTE scope discovery):**

If the user reveals new scope mid-EXECUTE ("oh wait, there's also a migration"), SCOPE evidence is now stale. Do not silently amend. Triage:

1. Pause the current `in_progress` task. Do not mark it completed or cancelled yet.
2. Re-classify if the new scope changes the class (e.g., schema migration entering the picture).
3. Per completed task, decide: *falsified* (claim is now false — e.g., "scope confirmation" against an incomplete diff) or *narrow-but-true* (claim still holds for what was checked, just incomplete coverage). Reopen falsified ones; augment narrow ones with follow-up tasks.
4. Add change-specific tasks for the newly discovered scope.
5. Resume EXECUTE only after the user confirms the reset shape.

Do not full-reset by default. Surgical reopen + augment is correct when most prior work is still factually true.

### 6. WRAP

When all tasks are `completed` or explicitly resolved:

- short summary: what class, how many tasks, what was skipped and why
- watch window: when to check monitoring (e.g., "first hour after deploy")
- feature flag cleanup date if any flag was introduced

## What to do at each task

`launch-playbook.md` is the source of task content (pre-launch checks, feature flag steps, staged rollout thresholds, monitoring, rollback templates). When executing a task, point the user to the relevant section. Do not paraphrase the playbook inline.

## Boundaries with `/qa` and `/e2e`

- `/qa` and `/e2e` produce verification evidence
- `/ship` consumes that evidence at GATE and SCOPE
- `/ship` does NOT re-run feature behavior tests

If a task requires QA evidence and none exists, the task is blocked. Tell the user to run `/qa` and return.

## Output discipline

- Do not produce a single-shot readiness report. The output IS the phased walk-through.
- Do not pre-fill task completion. The user confirms each task.
- Do not summarize `launch-playbook.md` inline at PLAN time. Show task titles, link to the playbook section.

## Red flags — stop and reset

- Generating tasks before SCOPE evidence
- Calling TaskCreate before user approval at PLAN
- Multiple tasks `in_progress` simultaneously
- Marking tasks `completed` without user confirmation
- Filling all 4 readiness areas (pre-launch/rollout/rollback/monitoring) for a low-risk change
- Reporting `Conditionally ready` when the actual answer is `Ready` (safety bias)
- Any output resembling the old single-shot `Decision/Blocking/Warnings/Readiness/Next actions` format

If any of these occur, stop. Restart from the phase where the rule was broken.

## References

| File | When to read |
|---|---|
| `references/curation-rules.md` | At CLASSIFY and PLAN — risk class criteria and default task sets |
| `references/launch-playbook.md` | At EXECUTE — full procedure content for each task (checklist items, rollout thresholds, rollback template) |

## Common rationalizations

| Excuse | Reality |
|---|---|
| "Change is small, no need for tasks" | Even low class has 3-5 tasks. Lightness comes from classification, not from skipping the format. |
| "Asking for approval breaks the flow" | Tasks created without approval get rejected. A 5-second review reduces friction. |
| "Already done it all, mark them all completed at once" | Bulk completion = single-shot regression. One-task-at-a-time confirmation IS the skill. |
| "Payment change but I'm out of time — just this once" | Sunk cost is not a readiness input. GATE blocks. |
| "Let me just inline the playbook content" | Playbook is the source. No inline summary. Link/reference only. |
| "Tools unavailable, judge from user testimony" | SCOPE requires tool calls. If unavailable, stop. |
| "Simulation/test context, so SCOPE bypass is fine" | Same rule. Simulation is not a SCOPE exemption. Stop. |
| "Detailed PLAN preview is more helpful" | Detailed previews get rubber-stamped with "all good". Titles + section links only. |
| "User just confirmed 1, 2, 3 — let me batch-update" | Pacing IS the discipline. One TaskUpdate per task, even on batch confirms. |
| "User wants to skip canary entirely — they have a point" | Engage with the empirical argument, but preserve the *purpose*. Propose a variant (team window, absolute-N canary), don't drop the goal. |
| "Scope changed mid-flight, easier to start over" | Falsified vs narrow-but-true. Reopen the falsified, augment the narrow. Don't throw out true work. |
