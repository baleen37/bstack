---
name: to-spec
description: Use when you have an approved design and need to write it as a spec document, before creating an implementation plan
disable-model-invocation: true
---

# Writing Spec

Write the approved design as a spec document. The spec is the binding authority
downstream: the plan argues from it, and implementers read both.

**Announce at start:** "I'm using the to-spec skill to write the spec document."

**Save specs to:** `docs/specs/YYYY-MM-DD-<topic>-design.md`
- (User preferences for spec location override this default)

## Input Gate

This skill writes down a design that has already been agreed. It does not
create one. If there is no approved design, stop and use `me:brainstorming`
first.

Structure the document however the work needs it — Goal, Scope, Non-goals, and
Verification cover most specs. The three rules below are what this repo needs
that a well-written spec would otherwise miss.

## Rule 1: `Discovery:` line

Put one line near the top recording how the design conversation actually went.
Downstream stages read this file, not your closing message.

| Value | Meaning |
|-------|---------|
| `full` | Interview ran to completion; nothing left silently assumed |
| `rapid-direct` | Input was already clear, so questions were few. **Not degraded** |
| `rapid-inferred` | Questions were skipped under instruction. **Degraded** — mark inferred content inline with `[Inferred: <source>]` |

`rapid-direct` and `rapid-inferred` are different states, not two words for the
same shortcut. One is a fast path through clear input; the other is a spec
written without the answers it wanted. Never label the second as the first.

## Rule 2: `## Open questions` rows are machine-readable

Unresolved decisions go in one `## Open questions` section, one row each, in
exactly this shape:

```
- [ ] <question>? Default now: <value>. — owner: <name/role>, due: <stage or date>
```

Writing the default as prose ("Proposal: repo-local, because…") reads fine and
is **not enough** — `me:to-plan` greps this section for unchecked rows
whose `due` has arrived. A row it cannot parse is a decision that silently
never gets made.

- **`Default now:`** — what happens if nobody answers. Keeps the chain moving.
- **`owner:`** — who decides. "me", a role, a team.
- **`due:`** — a later stage name (`to-plan`, `implementation`) or a date.
  A stage name means: this must close before that stage runs.

Keep the reasoning — the options table, the trade-offs, your recommendation —
in the body where it belongs. The row is the index; the body is the argument.

A row missing `owner` or `due` is not a real deferral. Ask once more; if it
still has neither, leave it unresolved in the body rather than sitting here
looking settled.

**Every open point ends Resolved or Deferred.** Resolved means the decision is
written into the body. Deferred means it has a row here. Nothing dangles.

**Never invent an answer to fill a gap.** An honest row beats a fabricated
requirement — the row is visible and the fabrication is not.

An empty `## Open questions` section is a good state, and it is the signal that
lets the next stage proceed without asking.

## Rule 3: no subjective language in requirements

Before finishing, search the spec for words that sound like requirements and
cannot be checked:

> user-friendly, easy to use, simple, intuitive, seamless, robust, efficient,
> effective, flexible, scalable, reliable, maintainable, fast, responsive,
> clean, modern, surprising

This is the one that survives careful writing — a phrase from the design
conversation ("should feel reliable", "shouldn't surprise anyone") gets carried
into the Goal verbatim and reads like a requirement while specifying nothing.

Each one gets a number ("resumes within 200ms"), a concrete description of the
observable behavior ("prints the phase list and waits for confirmation"), or an
Open questions row. Quoting the phrase as *rationale* for a decision is fine —
leaving it as the requirement is not.

Same for terms that quietly remove the requirement: *should*, *may*, *as
appropriate*, *if necessary*, *sufficient*, *etc.*, *and/or*. If it matters,
say it. If it does not, cut it.

## User Review Gate

Ask for review before moving on:

> "Spec written and committed to `<path>`. Please review it and let me know if
> you want to make any changes before we start writing out the implementation
> plan."

Wait. If they request changes, make them. Only proceed once they approve.
Commit the spec to git.

## Handoff

`to-plan` is the next step, and it is user-invoked — you cannot call it
yourself. End your turn by telling the user to run it:

> "Spec is committed. Run `/to-plan` when you're ready for the
> implementation plan."

Do not start planning inline, and do not invoke any other skill.
