# Phase boundaries

A **phase** is a chunk of work inside a session: the interview, the
implementation, the verification. The definition is loose on purpose — a phase
ends when you think *"ok, we're done with that"*.

The **phase boundary** is the gap between two phases, and it is the only place
this decision belongs. Mid-phase there is nothing to decide: continue, or split
what's left into subagents. Compacting mid-phase makes the agent lose the
thread.

## The five options

| Option | What it does |
| --- | --- |
| **Continue** | Stay in the session. No context switch at all. |
| **`/clear`** | Empty the context window and start from nothing. |
| **`me:handoff`** | Write a portable state handover and seed a session anywhere with it. |
| **Subagent** | Send the task to its own context window and get a report back. |
| **`/compact`** | Compress this context and seed a fresh session with the summary. |

## The tree

Work top to bottom at the boundary. The first **yes** wins.

**1. Can you continue in this session?** Two things make the answer yes: the
next phase needs this one as a **primary source**, or you have enough window
left for the next phase to fit. Interview → implementation is the standard yes —
the implementation wants the reasoning verbatim, not a summary of it. Continue
costs nothing and loses nothing, so rule it out before anything else.

**2. Is the context irrelevant to what comes next?** Is everything here — the
exploration, the decisions, the dead ends — disposable? Then **`/clear`**. It is
the cheapest move on the board: no time, and the whole window back. It also
isn't terminal, since the old session stays resumable.

The cost of getting this wrong is one-way. Clear a *relevant* context and you
lose the **why** behind what you built; no amount of reading the diff back
returns it.

**3. Do you need to hand off?** A handoff is narrow. You need it only when:

- swapping to a **different harness** (Claude Code → Codex),
- moving to a **different directory** or repo,
- sending the work to **someone else**,
- or forking a side task you found **mid-phase** without derailing what you're
  doing.

That list is the whole clause. What a handoff buys is **portability** — a file
that travels. If nothing is travelling, you don't need one.

**4. Can the task be done unattended?** Is it scoped tightly enough to run
with you away from the keyboard, no steering? Then send it to a **subagent** and
leave this session untouched. Code review is the standard case: the reviewer
reads the diff and reports, and you aren't needed while it does.

**5. Otherwise, `/compact`.** Relevant context, same harness, same directory,
and you need to stay in the loop: this is where the tree lands, and it lands
here often. Pass it an instruction (`/compact we're about to verify this area`)
so the summary keeps what the next phase needs.

`/compact` is the **default, not the first reach**. It sits at the bottom
because the four questions above it are all cheaper or more precise. The failure
mode when people start here is a fresh session that is confidently wrong about a
decision the summary flattened.

## Primary and secondary sources

Every move except **Continue** turns a **primary source** into a **secondary
source**: the session as it happened, replaced by a summary of it. The trade is
always the same shape.

| Source | Information | Noise | Room to move |
| --- | --- | --- | --- |
| Primary (Continue) | Full | Lots | Little |
| Secondary (`/compact`, handoff) | Lossy | Less | Lots |

This is why question 1 comes first. You only pay the lossiness when staying
costs more than it saves.

## Where the boundaries fall in the main flow

The chain in [SKILL.md](SKILL.md) has natural boundaries:

- **brainstorming → writing-spec**: Continue. The spec is written from the
  interview, and it wants the reasoning verbatim.
- **writing-spec → writing-plans**: usually Continue, since the plan argues
  from a spec you just discussed. If the interview ran long, `/compact` here —
  the spec file is now the primary source, so less is lost than usual.
- **writing-plans → executor**: the real boundary. The plan document carries
  everything the implementer needs, which is what makes each task's context
  disposable. `subagent-driven-development` exploits this by giving each task
  its own window.
- **implementation → verification**: `/compact` with an instruction, or
  Continue if the implementation was short. Verification wants to know what was
  built and why, and the diff alone doesn't say why.

## These are judgement calls

The questions are not objective — each has taste in it, and the same boundary
can go two ways on two days. The value is in asking them **in order**, at the
boundary rather than in the middle of the work.
