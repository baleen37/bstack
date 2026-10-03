---
name: ask
description: Ask which me skill or flow fits your situation.
disable-model-invocation: true
---

# Ask

Choose the smallest flow that fits the request. All skills below belong to `core`.

## Default development flow

1. **`core:brainstorming`** establishes intent, challenges unresolved decisions with its grilling reference, and invokes `core:domain-modeling` when domain terms or decisions need recording. A small bounded change needs a short approved design; multi-step work continues through a written spec and plan.
2. **`core:writing-plans`** turns the approved design or requirements into one implementation plan under `docs/plans/`.
3. **`core:executing-plans`** implements in the current session, or **`core:subagent-driven-development`** implements with fresh task agents and review gates. Choose based on task dependencies, available tools, and the user's preference; preserve a choice already made.
4. **`core:verify`** exercises the changed flow. **`core:code-review`** performs the actual review; **`core:requesting-code-review`** arranges a review and **`core:receiving-code-review`** handles feedback.
5. **`core:create-pr`** writes the body from its PR-writing reference and handles commit/push/PR. **`core:ship`** handles an explicitly requested release or deployment.

TDD comes from `core:tdd`; failures go through `core:diagnosing-bugs`. General design and implementation need no tracker setup.

## Optional routes

| Situation | Route |
| --- | --- |
| Large unresolved uncertainty across sessions | `core:wayfinder` → `core:writing-spec` → written-spec review → `core:writing-plans` → chosen executor |
| Design question needs a concrete answer | `core:prototype` or `core:research`, then return the findings to the design |
| Incoming bugs or requests | `core:triage`, then approved requirements → `core:writing-plans` → chosen executor |
| Requested tracker tickets | `core:to-tickets` publishes slices of the approved spec/plan; the implementation plan remains the execution authority |
| Broken behavior or performance regression | `core:diagnosing-bugs` → regression test with `core:tdd` → `core:verify` → `core:code-review` |

`core:wayfinder` resolves decisions, not implementation tasks. When uncertainty is resolved, synthesize the linked decisions with `core:writing-spec`, review that artifact, and plan execution. Ticket publication is optional and never creates a second execution graph automatically.

## Independent tools

- **Codebase:** `core:improve-codebase-architecture` finds candidates; `core:codebase-design` supplies module vocabulary. Take a selected change into brainstorming.
- **Communication:** `core:to-questionnaire` gathers someone else's input; `core:wait-what` re-explains a message; `core:writing-rfcs` writes technical decisions; `core:writing-for-agents` guides agent documents.
- **Session:** `core:handoff` carries context across a harness, directory, colleague, or side task; `core:retro` improves the environment after a build; `core:diagnosing-workflow` investigates a failed session.
- **Learning and operations:** `core:learn` resumes a topic under `~/.skills/learn/`; `core:wizard` guides human-only steps; `core:browser` operates the real interface.
- **Execution support:** `core:using-git-worktrees`, `core:dispatching-parallel-agents`, `core:competitive-agents`, `core:e2e-scenario-testing`, `core:simplify`, `core:verification-before-completion`, and `core:finishing-a-development-branch` support the selected flow.

## Configuration and context

Use **`core:setup`** only when configuring tracker-backed features or a project's domain-doc conventions. `core:writing-spec` saves locally by default; publishing to a tracker is an explicit choice.

Read [PHASE-BOUNDARIES.md](PHASE-BOUNDARIES.md) when choosing whether to continue, compact, hand off, or delegate at a phase boundary. Keep the approved spec, plan, and execution ledger reachable across that boundary.
