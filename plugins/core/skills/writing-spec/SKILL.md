---
name: writing-spec
description: "Turn the conversation or resolved decision map into a local spec; publish to a tracker only when explicitly requested."
---

This skill takes the current conversation context and codebase understanding and produces a spec. Do NOT interview the user; just synthesize what you already know.

Save to `docs/specs/YYYY-MM-DD-<topic>-design.md` by default, unless the user names another location. Tracker configuration is unnecessary for a local spec. When tracker publication is explicitly requested, read `docs/agents/issue-tracker.md` and the triage label mapping; ask the user to invoke `core:setup` only if that configuration is missing.

When entering from `core:wayfinder`, read the map and relevant linked resolutions, preserving the decisions and remaining constraints in the spec.

## Process

1. Explore the repo to understand the current state of the codebase, if you haven't already. Use the project's domain glossary vocabulary throughout the spec, and respect any ADRs in the area you're touching.

2. Sketch out the seams at which you're going to test the feature. Existing seams should be preferred to new ones. Use the highest seam possible. If new seams are needed, propose them at the highest point you can. The fewer seams across the codebase, the better - the ideal number is one.

Check with the user that these seams match their expectations.

3. Write the spec using the template below and save the local file. If the user explicitly chose tracker publication, publish that same spec using the configured tracker and label vocabulary.

4. Self-review for placeholders, contradictions, scope, and ambiguity. Show the saved artifact for user review. Once the written spec is approved, invoke `core:writing-plans`, then use the selected executor. Ticket publication through `core:to-tickets` is optional and does not replace the implementation plan.

<spec-template>

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

Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it within the relevant decision and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

## Testing Decisions

A list of testing decisions that were made. Include:

- A description of what makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (i.e. similar types of tests in the codebase)

## Out of Scope

A description of the things that are out of scope for this spec.

## Further Notes

Any further notes about the feature.

</spec-template>
