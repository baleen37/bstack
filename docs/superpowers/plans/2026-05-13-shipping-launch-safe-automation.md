# Shipping Launch Safe Automation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)
> or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax
> for tracking.

**Goal:** Improve `shipping-and-launch` so agents automatically perform safe launch-preparation work while
stopping for approval before risky or externally visible actions.

**Architecture:** Modify only the existing `plugins/me/skills/shipping-and-launch/SKILL.md` skill. Add an
automation policy, execution workflow, decision categories, and `/ship` relationship near the top while
preserving the existing launch checklist, feature flag, staged rollout, monitoring, and rollback reference
content.

**Tech Stack:** Markdown skill file with YAML frontmatter, bstack `me` plugin conventions, markdownlint, BATS.

---

## File Structure

- Modify: `plugins/me/skills/shipping-and-launch/SKILL.md` — add safe automation behavior and clarify handoff to `/ship`.
- No README change planned because the lifecycle summary already describes this skill accurately.

### Task 1: Add safe automation policy

**Files:**

- Modify: `plugins/me/skills/shipping-and-launch/SKILL.md`

- [ ] **Step 1: Read the existing skill**

Run: `sed -n '1,120p' plugins/me/skills/shipping-and-launch/SKILL.md`
Expected: YAML frontmatter, overview, when-to-use, and pre-launch checklist are visible.

- [ ] **Step 2: Insert automation policy after Overview**

Add a new `## Automation Policy` section after the Overview paragraph. The section must say the agent
should first do safe, read-only or local reversible work automatically, then stop for approval before risky
actions.

Include these auto-allowed bullets:

```markdown
The agent may do these without asking first:

- Inspect git status, diffs, recent commits, changed files, and PR/CI status.
- Run local read-only or reversible verification such as tests, lint, type checks, builds, audits, and focused smoke checks.
- Draft launch artifacts: rollout plan, rollback plan, monitoring checklist, post-launch verification checklist, and release notes.
- Identify missing owners, dashboards, feature flags, environment variables, documentation, or runbooks.
- Classify findings as `AUTO-COMPLETED`, `NEEDS_APPROVAL`, `BLOCKED`, or `READY_FOR_SHIP_REVIEW`.
```

Include these approval-required bullets:

```markdown
The agent must ask before doing these:

- Push branches, create or merge PRs, tag releases, or publish packages.
- Deploy to staging or production, trigger release workflows, or change infrastructure.
- Modify feature flags, production configuration, secrets, environment variables, DNS, SSL, or databases.
- Send external notifications, Slack messages, GitHub comments, status page updates, or customer-facing announcements.
- Execute rollback, destructive commands, data migrations, or irreversible cleanup.
```

- [ ] **Step 3: Keep existing checklist content intact**

Do not remove the existing `## The Pre-Launch Checklist` section or its subsections. Only add the new policy before it.

- [ ] **Step 4: Verify policy presence**

Run: `grep -n "Automation Policy\|AUTO-COMPLETED\|NEEDS_APPROVAL\|BLOCKED\|READY_FOR_SHIP_REVIEW\|must ask" plugins/me/skills/shipping-and-launch/SKILL.md`
Expected: The new section and all decision labels are present.

### Task 2: Add execution workflow and `/ship` handoff

**Files:**

- Modify: `plugins/me/skills/shipping-and-launch/SKILL.md`

- [ ] **Step 1: Insert execution workflow after Automation Policy**

Add a new `## Execution Workflow` section after `## Automation Policy`.

The workflow must contain these steps:

```markdown
1. Identify the launch type, changed files, blast radius, and whether production systems are affected.
2. Run safe automatic checks first: local verification, CI/PR status reads, dependency/security audits when available, and documentation checks.
3. Draft the launch artifacts that can be prepared locally: rollout stages, rollback triggers and procedure, monitoring targets, owners, and post-launch checks.
4. Categorize every item into `AUTO-COMPLETED`, `NEEDS_APPROVAL`, `BLOCKED`, or `READY_FOR_SHIP_REVIEW`.
5. Stop on `BLOCKED` items and report the exact evidence.
6. Ask before any `NEEDS_APPROVAL` action.
7. When preparation is complete and the change is production-bound, hand off to `/ship` for the final GO/NO-GO decision.
```

- [ ] **Step 2: Add decision category definitions**

Add a `## Decision Categories` section after the execution workflow.

Use these definitions:

```markdown
- `AUTO-COMPLETED`: Safe checks or drafts the agent completed locally with evidence.
- `NEEDS_APPROVAL`: Risky, externally visible, shared-state, or hard-to-reverse actions that require user approval.
- `BLOCKED`: A launch blocker such as failing tests, missing rollback path, unknown owner, missing monitoring, unresolved security risk, or unverifiable production impact.
- `READY_FOR_SHIP_REVIEW`: Launch preparation is complete enough for `/ship` to run specialist review and produce GO/NO-GO.
```

- [ ] **Step 3: Add relationship to `/ship`**

Add a short `## Relationship to /ship` section after decision categories.

The section must say:

```markdown
Use `shipping-and-launch` to prepare launch artifacts and perform safe automatic checks. Use `/ship` when the question is whether the current change is ready to go live. `/ship` performs the specialist fan-out review and final GO/NO-GO synthesis; this skill prepares the evidence that `/ship` consumes.
```

- [ ] **Step 4: Verify workflow and handoff presence**

Run: `grep -n "Execution Workflow\|Decision Categories\|Relationship to /ship\|READY_FOR_SHIP_REVIEW\|GO/NO-GO" plugins/me/skills/shipping-and-launch/SKILL.md`
Expected: The workflow, category definitions, and `/ship` relationship are present.

### Task 3: Validate formatting and repository checks

**Files:**

- Modify: `plugins/me/skills/shipping-and-launch/SKILL.md`

- [ ] **Step 1: Run markdownlint for the changed skill and plan**

Run: `pre-commit run markdownlint --files plugins/me/skills/shipping-and-launch/SKILL.md docs/superpowers/plans/2026-05-13-shipping-launch-safe-automation.md`
Expected: PASS. If it fails for line length or blank-line formatting, fix only formatting in those files and rerun.

- [ ] **Step 2: Run project tests**

Run: `bats tests/`
Expected: PASS. If BATS is unavailable or tests fail, report the exact failure and do not claim full verification.

- [ ] **Step 3: Check diff scope**

Run: `git diff -- plugins/me/skills/shipping-and-launch/SKILL.md docs/superpowers/plans/2026-05-13-shipping-launch-safe-automation.md`
Expected: Diff only contains the shipping-and-launch safe automation policy/workflow and this implementation plan.

## Self-Review

- Spec coverage: The plan covers safe automation, approval gates, execution workflow, decision categories,
  `/ship` handoff, existing content preservation, and verification.
- Placeholder scan: No TBD/TODO/later placeholders remain.
- Type consistency: This plan edits Markdown only; all decision category names are consistent across tasks.
