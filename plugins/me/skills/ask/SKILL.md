---
name: ask
description: Ask which me skill or flow fits your situation.
disable-model-invocation: true
---

# Ask

Choose the smallest flow that fits the request. All skills below belong to `me`.

## Default development flow

1. **`me:brainstorming`** establishes intent, challenges unresolved decisions with its grilling reference, and invokes `me:domain-modeling` when domain terms or decisions need recording. A small bounded change needs a short approved design; multi-step work continues through a written spec and plan.
2. **`me:writing-plans`** turns the approved design or requirements into one implementation plan under `docs/plans/`.
3. **`me:executing-plans`** implements in the current session, or **`me:subagent-driven-development`** implements with fresh task agents and review gates. Choose based on task dependencies, available tools, and the user's preference; preserve a choice already made.
4. **`me:verify`** exercises the changed flow. **`me:code-review`** performs the actual review; **`me:requesting-code-review`** arranges a review and **`me:receiving-code-review`** handles feedback.
5. **`me:create-pr`** writes the body from its PR-writing reference and handles commit/push/PR. **`me:ship`** handles an explicitly requested release or deployment.

TDD comes from `me:tdd`; failures go through `me:diagnosing-bugs`. General design and implementation need no tracker setup.

## Optional routes

| Situation | Route |
| --- | --- |
| Large unresolved uncertainty across sessions | `me:wayfinder` → `me:writing-spec` → written-spec review → `me:writing-plans` → chosen executor |
| Design question needs a concrete answer | `me:prototype` or `me:research`, then return the findings to the design |
| Incoming bugs or requests | `me:triage`, then approved requirements → `me:writing-plans` → chosen executor |
| Requested tracker tickets | `me:to-tickets` publishes slices of the approved spec/plan; the implementation plan remains the execution authority |
| Broken behavior or performance regression | `me:diagnosing-bugs` → regression test with `me:tdd` → `me:verify` → `me:code-review` |

`me:wayfinder` resolves decisions, not implementation tasks. When uncertainty is resolved, synthesize the linked decisions with `me:writing-spec`, review that artifact, and plan execution. Ticket publication is optional and never creates a second execution graph automatically.

## Independent tools

- **Codebase:** `me:improve-codebase-architecture` finds candidates; `me:codebase-design` supplies module vocabulary. Take a selected change into brainstorming.
- **Communication:** `me:to-questionnaire` gathers someone else's input; `me:wait-what` re-explains a message; `me:writing-rfcs` writes technical decisions; `me:writing-for-agents` guides agent documents.
- **Session:** `me:handoff` carries context across a harness, directory, colleague, or side task; `me:retro` improves the environment after a build; `me:diagnosing-workflow` investigates a failed session.
- **Learning and operations:** `me:learn` resumes a topic under `~/.bstack/learn/`; `me:wizard` guides human-only steps; `me:browser` operates the real interface.
- **Execution support:** `me:using-git-worktrees`, `me:dispatching-parallel-agents`, `me:competitive-agents`, `me:e2e-scenario-testing`, `me:simplify`, `me:verification-before-completion`, and `me:finishing-a-development-branch` support the selected flow.

## Configuration and context

Use **`me:setup`** only when configuring tracker-backed features or a project's domain-doc conventions. `me:writing-spec` saves locally by default; publishing to a tracker is an explicit choice.

Read [PHASE-BOUNDARIES.md](PHASE-BOUNDARIES.md) when choosing whether to continue, compact, hand off, or delegate at a phase boundary. Keep the approved spec, plan, and execution ledger reachable across that boundary.
