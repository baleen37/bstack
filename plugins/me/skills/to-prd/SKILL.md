---
name: to-prd
description: Turn the current conversation context into a PRD, submit it as a GitHub issue, and optionally break it into independently-grabbable implementation issues. Use when user wants to create a PRD, or convert a plan/spec into implementation tickets.
disable-model-invocation: true
---

This skill takes the current conversation context and codebase understanding and produces a PRD. Do NOT interview the user — just synthesize what you already know.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already.

2. Sketch out the major modules you will need to build or modify to complete the implementation. Actively look for opportunities to extract deep modules that can be tested in isolation.

A deep module (as opposed to a shallow module) is one which encapsulates a lot of functionality in a simple, testable interface which rarely changes.

Check with the user that these modules match their expectations. Check with the user which modules they want tests written for.

3. Write the PRD using the template below and submit it as a GitHub issue.

<prd-template>

## Problem Statement

The problem that the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A LONG, numbered list of user stories. Each user story should be in the format of:

1. As an <actor>, I want a <feature>, so that <benefit>

<user-story-example>
1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending
</user-story-example>

This list of user stories should be extremely extensive and cover all aspects of the feature.

## Implementation Decisions

A list of implementation decisions that were made. This can include:

- The modules that will be built/modified
- The interfaces of those modules that will be modified
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets. They may end up being outdated very quickly.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this PRD.

## Further Notes

Any further notes about the feature.

</prd-template>

## Optional: break the PRD into implementation issues

When the user wants implementation tickets (not just the PRD), break the work into **tracer bullet** issues — thin vertical slices that each cut through ALL layers (schema, API, UI, tests) end-to-end, never a horizontal slice of one layer.

<vertical-slice-rules>
- Each slice delivers a narrow but COMPLETE path through every layer
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- Mark each slice HITL (needs human decision/review) or AFK (mergeable without interaction); prefer AFK
</vertical-slice-rules>

Present the breakdown as a numbered list — for each slice show **Title**, **Type** (HITL/AFK), **Blocked by**, and **User stories covered**. Ask whether the granularity and dependencies are right, and iterate until the user approves.

Then create one GitHub issue per approved slice with `gh issue create`, in dependency order (blockers first) so "Blocked by" can reference real issue numbers. Each issue body: parent reference (`#<prd-issue>`), "What to build" (end-to-end behavior, not layer-by-layer), and "Acceptance criteria" checkboxes. Do NOT close or modify the parent PRD issue.
