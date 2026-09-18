---
name: ask
description: Ask which skill or flow fits the situation. A router over the me skills.
disable-model-invocation: true
---

# Ask

You don't remember every skill, so ask.

A **flow** is a path through the skills. Most work runs along one **main
flow**; two **on-ramps** merge onto it, and the rest are standalone or a gate
that fires on its own.

## The main flow: idea → shipped

1. **`me:brainstorming`** classifies the work first — **spike** (a question to
   answer), **bounded** (one existing flow to change), or **architectural**
   (everything else) — then interviews you in rounds over a design tree until
   the frontier is empty. The classification decides how much of the rest of
   this flow you need: a spike ends at a reported recommendation, a bounded
   task goes straight to implementation with no plan document, and only
   architectural work continues down this list.

2. **`me:writing-spec`** writes the approved design to
   `docs/specs/YYYY-MM-DD-<topic>-design.md` and commits it. It owns the spec:
   the template, the `Discovery:` line recording how the interview actually
   went, the `## Open questions` rows, and the review gate. It will not invent
   a design — with no approved one, it sends you back to brainstorming.

3. **`me:writing-plans`** turns the spec into
   `docs/plans/YYYY-MM-DD-<feature>.md`: tasks sized to one test cycle, each
   with exact file paths and a red-green step list. It is gated on the spec
   existing, because a plan with nothing to be checked against is unreviewable.

4. **Pick an executor.** Both read the plan and hand off to
   `me:finishing-a-development-branch`:
   - **`me:subagent-driven-development`** stays in this session and dispatches
     one implementer subagent per task, reviewing each before moving on. The
     default.
   - **`me:executing-plans`** runs the plan in a separate session with review
     checkpoints. Reach for it when the work wants its own context window.

5. **`me:finishing-a-development-branch`** verifies tests, then offers exactly
   three choices: merge locally, push and open a PR, or leave the branch. It
   stops there — shipping is a separate decision you make by hand.

`me:tdd` runs underneath steps 4 and 5: it is the reference behind the
red-green loop those tasks are written as. Reach for it directly when you want
a behaviour built test-first without a plan.

## On-ramps

A starting situation that generates work, then joins the main flow.

- **Something is broken and you don't know why** → **`me:diagnosing-bugs`**.
  For the hard ones: the bug that survives a first read, the flake, the
  regression between two known-good states. It refuses to theorise until it has
  one command that goes red on *this* bug, then fixes with a regression test.
  `me:verify` hands off here when a FAIL has no obvious cause.

- **You need facts before you can decide** → **`me:research`**. Delegates the
  reading to a background agent, which investigates against primary sources and
  leaves a cited Markdown file. Keep working while it reads. What it produces is
  material to take *into* brainstorming, not a replacement for the thinking.

## Verification

- **`me:verify`** answers "does this actually work?" and reports `PASS`,
  `PARTIAL`, or `FAIL` with evidence. Model-invoked, so it fires on "verify
  this" or "qa".
- **`me:e2e-scenario-testing`** drives a running app through its real
  interface — web UI, CLI, or TUI — with scenario cards carrying falsifiable
  assertions. For what unit tests cannot reach.
- **`me:verification-before-completion`** is the gate, not a task: it fires
  when you are about to call something done, and demands fresh command output
  before the claim. Evidence before assertions.

## Review

Two scopes, and the scope picks the skill:

- **`me:code-review`** reviews a **range** — a branch, a PR, everything since a
  tag — on two axes in parallel subagents: **Standards** (does it follow the
  repo's documented rules, plus a Fowler smell baseline) and **Spec** (does it
  do what the spec asked). Reported side by side and never merged, because a
  change can pass one axis and fail the other.
- **`me:requesting-code-review`** dispatches a single reviewer against two SHAs
  with purpose-built context rather than your session history. The per-task
  case, and what `me:subagent-driven-development` calls after each task.
- **`me:receiving-code-review`** is for the other side: processing feedback
  with technical rigour instead of performative agreement. Verify each claim
  before implementing it, and push back with reasoning when a reviewer is
  wrong.

## Ship

Neither of these is reached automatically — you invoke them.

- **`me:create-pr`** commits, pushes, opens the PR, and can wait for checks or
  merge. It carries the tested preflight (base sync, conflict detection) and
  merge-wait scripts.
- **`me:ship`** is the deploy itself: pre-deploy checks, the deploy, and
  post-deploy verification with a rollback path.

## Documents

- **`me:writing-prds`** — product requirements: the problem, the users, what
  success looks like. Before engineering starts.
- **`me:writing-rfcs`** — technical design docs, architecture proposals,
  migration plans, cross-team decisions.

Both sit upstream of the main flow; a PRD or RFC is something you take *into*
brainstorming.

## Parallel work

- **`me:dispatching-parallel-agents`** — two or more independent tasks with no
  shared state and no ordering between them.
- **`me:competitive-agents`** — one problem, several valid approaches, no
  obvious winner. Run them against each other and compare.
- **`me:using-git-worktrees`** — isolate a workspace before either of the
  above, or before executing a plan.

## Also here

- **`me:browser`** — browser automation, and anything needing your logged-in
  accounts, history, or open tabs.
- **`me:write-skill`** — write or fix a `SKILL.md`, prove it against a
  no-skill baseline, tune it with SkillOpt.

## Phase boundaries

Between two phases of a session — the interview, the implementation, the
verification — you have five options, and picking between them is the fuzziest
decision here:

- **Continue**: stay put. Costs nothing, loses nothing.
- **`/clear`**: empty the window, when nothing here matters to what's next.
- **Handoff**: write a portable file. Narrow — only for a different harness, a
  different directory, someone else, or forking a side task mid-phase.
- **Subagent**: send a tightly-scoped task to its own window, get a report back.
- **`/compact`**: compress and reseed. The **default**, at the bottom of the
  tree rather than the first reach.

Read [PHASE-BOUNDARIES.md](PHASE-BOUNDARIES.md) for the ordered tree: the five
questions, why the primary-source cost makes **Continue** the one to rule out
first, and where the boundaries fall in the main flow above. Decide **at** a
boundary; mid-phase, continue or split the rest into subagents.

## The mattpocock-skills plugin

Also installed, and this router covers it too. Its flows are built around an
**issue tracker** where `me`'s are built around files in `docs/`, so they are an
alternative to the main flow above rather than a part of it. Most need
`/setup-matt-pocock-skills` run once per repo first.

**Vocabulary** — references, not sessions. Reach for them when the *words*, not
the process, are the problem:

- **`codebase-design`** — the deep-module vocabulary: module, interface, depth,
  seam, adapter, leverage, locality. `me:tdd` speaks it when deciding which
  seam to test at.
- **`domain-modeling`** — sharpen the project's domain language: challenge a
  fuzzy term, resolve an overloaded word, record a hard-to-reverse decision as
  an ADR. Keeps a `CONTEXT.md` glossary. Note this repo has neither
  `CONTEXT.md` nor `docs/adr/`, so it would start both.

**Tracker-based flow** — the alternative to the main flow, for work tracked as
issues rather than files: `to-tickets` splits a spec into tracer-bullet tickets
carrying blocking edges, `implement` builds one ticket, and `implement-spec`
builds a whole spec across parallel implementers. Both drive `me:tdd` and close
out with `me:code-review`.

**Big or messy starting points:**

- **`wayfinder`** — a greenfield project or feature build too large for one
  session. Charts a map of decision tickets and resolves them one at a time,
  producing **decisions, not deliverables**. Where `me:brainstorming` sharpens
  an idea you can hold in one session, this is for the one you can't.
- **`triage`** — bug reports and feature requests piling up. Moves issues
  through triage roles and emits agent-ready ones. Only for issues you did
  *not* create.
- **`improve-codebase-architecture`** — spare-time upkeep. Surveys the codebase
  for deepening opportunities and reports them as HTML; picking one generates an
  idea to take into `me:brainstorming`.

**Standalone:**

- **`prototype`** — throwaway code answering one design question: does this
  state model feel right, what should this UI look like.
- **`resolving-merge-conflicts`** — works an in-progress merge or rebase hunk by
  hunk, resolving by intent rather than by picking lines. Never `--abort`.
- **`wizard`** — generates an interactive bash script for steps only a human can
  do: provisioning, credentials, CI secrets, a third-party dashboard.
- **`handoff`** — compacts this conversation into a portable file for another
  agent. See Phase boundaries above for when a handoff is the right move.
- **`to-questionnaire`** — the blocker is in *someone else's* head; writes them
  a questionnaire to fill in.
- **`wait-what`** — fire it the moment a message doesn't land; the agent
  re-pitches in plainer language.
- **`teach`** — learn a concept over several sessions, using the current
  directory as a stateful workspace.
- **`writing-for-agents`** — the reference for writing documents agents consume.
  Deeper on information design than `me:write-skill`, which is stronger on
  proving a skill against a baseline. Read both when writing a skill.
- **`setup-matt-pocock-skills`** — run once per repo to configure the issue
  tracker, triage labels, and doc layout the flows above assume.

## When nothing here fits

Say so rather than forcing a match. A skill invoked because it was the nearest
name costs more than no skill at all: it drags a process over work that did not
need one. The honest answer is sometimes "just do it".
