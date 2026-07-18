# Story Loop Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add provider-neutral `e2e-scenario-testing` and `story-loop` skills
to the personal `me` plugin.

**Architecture:** Keep scenario execution guidance in
`e2e-scenario-testing` and repository-wide inventory, ledger, delegation, and
quality-cycle orchestration in `story-loop`. Both are ordinary plugin skills,
so Claude Code and Codex discover the same source without a duplicated
Claude-only command.

**Tech Stack:** Markdown Agent Skills, Claude Code plugin layout, Codex plugin
skill discovery, BATS structural tests, markdownlint.

## Global Constraints

- Keep the existing `plugins/me/skills/e2e/SKILL.md` unchanged.
- Do not add `agents/openai.yaml` or supporting files.
- Do not change plugin manifests or release versions.
- Do not add tests that assert skill prose or frontmatter content.
- Keep the canonical scenario ledger single-writer.
- Put runner delegation details in `story-loop`; do not attribute absent
  runner templates or per-run ledgers to `e2e-scenario-testing`.

---

### Task 1: Add Real-Interface Scenario Testing

**Files:**

- Create: `plugins/me/skills/e2e-scenario-testing/SKILL.md`
- Modify: `plugins/me/README.md`

**Interfaces:**

- Consumes: A running web UI, CLI, or TUI and a user-visible behavior to test.
- Produces: The `e2e-scenario-testing` skill and its scenario-card contract:
  `What this covers`, `Pre-state`, `Steps`, `Expected`, `Cleanup`, and
  `Sharp edges`.

- [x] **Step 1: Add the upstream skill as one self-contained file**

Use the public source at commit `e5faf42e`:
`obra/dotfiles/.claude/skills/e2e-scenario-testing/SKILL.md`. Preserve its
frontmatter, scenario-card format, fresh-build and isolation rules, browser and
tmux recipes, authoritative-state checks, evidence requirements, cleanup, and
per-assertion pass/fail reporting. Do not add orchestration that belongs to
`story-loop`.

- [x] **Step 2: Expose the skill in the me plugin README**

Add this entry under `Verify`, after `e2e`:

```markdown
- `e2e-scenario-testing` — Verify a running web UI, CLI, or TUI with reusable scenario cards and falsifiable assertions.
```

- [x] **Step 3: Validate the skill and documentation**

Run:

```bash
python3 /Users/jito.hello/.codex/skills/.system/skill-creator/scripts/quick_validate.py plugins/me/skills/e2e-scenario-testing
bunx markdownlint-cli2 plugins/me/skills/e2e-scenario-testing/SKILL.md plugins/me/README.md
```

Expected: validator reports `Skill is valid!`; markdownlint reports zero
issues.

- [x] **Step 4: Commit the scenario-testing skill**

```bash
git add plugins/me/skills/e2e-scenario-testing/SKILL.md plugins/me/README.md
git commit -m "feat(me): add e2e scenario testing skill"
```

### Task 2: Add the Repository-Wide Story Loop

**Files:**

- Create: `plugins/me/skills/story-loop/SKILL.md`
- Modify: `plugins/me/README.md`

**Interfaces:**

- Consumes: An optional area or surface from the user's request and the
  `e2e-scenario-testing` card contract.
- Produces: Scenario cards under `test/scenarios/`, the canonical
  `test/scenarios/LEDGER.md`, and a bounded `test -> fix -> re-test` loop.

- [x] **Step 1: Adapt the upstream command into a provider-neutral skill**

Use `obra/dotfiles/.claude/commands/story-loop.md` as the behavioral source.
Replace command-only frontmatter with:

```yaml
---
name: story-loop
description: Use when cataloging a repository's externally observable capabilities as end-to-end scenarios and driving them through test, fix, and re-test until verified
---
```

Replace `$ARGUMENTS` with the area or surface named by the user; use the whole
repository when none is given. Require `e2e-scenario-testing` before Phase 0.
Keep the card naming, ledger schema, status flow, defect taxonomy, three-phase
cycle, checkpoint rules, and three-iteration safety cap.

Add a self-contained runner contract to `story-loop`: each disposable runner
gets an isolated workdir and assigned cards, cannot edit product behavior,
may retry one suspected flake once, and must return per-assertion verdicts with
concrete evidence. The main agent remains the only writer of the canonical
ledger and transcribes runner results itself.

- [x] **Step 2: Expose the workflow in the me plugin README**

Add this entry under `Verify`, after `e2e-scenario-testing`:

```markdown
- `story-loop` — Inventory repository capabilities and loop through scenario testing, fixes, and fresh verification.
```

- [x] **Step 3: Validate the skill and documentation**

Run:

```bash
python3 /Users/jito.hello/.codex/skills/.system/skill-creator/scripts/quick_validate.py plugins/me/skills/story-loop
bunx markdownlint-cli2 plugins/me/skills/story-loop/SKILL.md plugins/me/README.md
bats tests/integration/plugin_loading.bats tests/integration/cross_plugin_interactions.bats
git diff --check
```

Expected: both skill and plugin structural validation pass, markdownlint
reports zero issues, BATS reports no failures, and `git diff --check` is
silent.

- [x] **Step 4: Inspect scope and commit**

Confirm `git diff --stat HEAD^` contains only both new skills, the README, and
the approved design/plan artifacts. Then run:

```bash
git add plugins/me/skills/story-loop/SKILL.md plugins/me/README.md docs/superpowers/plans/2026-07-18-story-loop-skills.md
git commit -m "feat(me): add story loop skill"
```
