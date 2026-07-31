# bstack Collaboration Plugin Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove bstack-owned Jira, Notion, and Slack plugins from local clients and the bstack marketplace source.

**Architecture:** `.claude-plugin/marketplace.json` is the source manifest and `.agents/plugins/marketplace.json` is generated from it. Delete the three source plugins, replace their tests with an absence assertion, and regenerate Codex artifacts. Baleen Marketplace imports bstack with `plugins/*`, so a normal source refresh propagates the result without an edit to `sources.json`.

**Tech Stack:** Bash, Bats, JSON manifests, Claude Code CLI, Codex CLI.

## Global Constraints

- Remove only bstack-owned `jira`, `notion`, and `slack`.
- Preserve third-party Slack plugins.
- Do not edit marketplace caches or `/Users/jito.hello/dev/wooto/baleen-marketplace/sources.json`.

---

## File Structure

- Modify: `.claude-plugin/marketplace.json` and regenerated `.agents/plugins/marketplace.json`.
- Delete: `plugins/jira/`, `plugins/notion/`, `plugins/slack/`, `tests/jira/`, and `tests/fixtures/jira/`.
- Modify: `tests/official_mcp_plugins.bats` and `tests/run-all-tests.sh`.

### Task 1: Remove only the local bstack installations

**Files:** user-level Claude and Codex plugin registries through their CLIs.

- [ ] **Step 1: Record current state**

Run:

```bash
codex plugin list | rg '^(jira|notion|slack)@'
claude plugin list | rg -A3 '^  ❯ (jira|notion|slack)@'
```

Expected: only the bstack IDs identified in the design are candidates for removal.

- [ ] **Step 2: Remove bstack IDs**

Run:

```bash
codex plugin remove jira@baleen-marketplace
codex plugin remove slack@baleen-marketplace
claude plugin uninstall jira@baleen-marketplace
claude plugin uninstall notion@baleen-marketplace
```

Expected: absent IDs are recorded as absent; no third-party Slack plugin is removed.

- [ ] **Step 3: Verify removal**

Run the Step 1 commands. Expected: none of the four removal commands' IDs is installed.

### Task 2: Establish and update the test contract

**Files:**
- Modify: `tests/official_mcp_plugins.bats`
- Modify: `tests/run-all-tests.sh`
- Delete: `tests/jira/`, `tests/fixtures/jira/`

- [ ] **Step 1: Add a failing marketplace-absence test**

Add this Bats test to `tests/official_mcp_plugins.bats`:

```bash
@test "marketplace excludes retired collaboration plugins" {
    local manifest="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
    ! jq -e '.plugins[] | select(.name == "jira" or .name == "notion" or .name == "slack")' "$manifest"
}
```

- [ ] **Step 2: Verify the test is red**

Run `bats tests/official_mcp_plugins.bats`.

Expected: fail because the current marketplace manifest contains all three names.

- [ ] **Step 3: Remove obsolete test coverage**

Replace the Jira/Notion/Slack manifest and endpoint tests with the existing Datadog-only contract. Remove `jira` from `test_dirs` in `tests/run-all-tests.sh`, then delete `tests/jira/` and `tests/fixtures/jira/`.

### Task 3: Remove source plugins and generate artifacts

**Files:**
- Modify: `.claude-plugin/marketplace.json`, `.agents/plugins/marketplace.json`
- Delete: `plugins/jira/`, `plugins/notion/`, `plugins/slack/`

- [ ] **Step 1: Delete source packages and manifest entries**

Delete the three plugin directories. Delete their complete objects from the `plugins` array in `.claude-plugin/marketplace.json`.

- [ ] **Step 2: Regenerate Codex artifacts**

Run `npm run sync:codex`.

Expected: `.agents/plugins/marketplace.json` contains no Jira, Notion, or Slack bstack entry.

- [ ] **Step 3: Verify green**

Run:

```bash
bats tests/official_mcp_plugins.bats
npm run check:codex
rg -n 'plugins/(jira|notion|slack)|"(jira|notion|slack)"' .claude-plugin .agents plugins scripts tests .github
```

Expected: the first two commands pass; `rg` exits 1 with no matches.

### Task 4: Full verification and catalog propagation

**Files:** all Task 2 and Task 3 paths.

- [ ] **Step 1: Run regressions**

Run:

```bash
npm test
git diff --check
git status --short
```

Expected: tests and whitespace checks pass; status contains only scoped changes and the implementation plan.

- [ ] **Step 2: Confirm marketplace propagation contract**

Run `jq -r '.bstack.paths[]' /Users/jito.hello/dev/wooto/baleen-marketplace/sources.json`.

Expected: `plugins/*`, confirming no static Baleen Marketplace deletion is needed.

- [ ] **Step 3: Commit the removal**

Run:

```bash
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json plugins tests
git commit -m "chore: remove retired collaboration plugins"
```

Expected: a focused source-removal commit.

- [ ] **Step 4: Trigger normal marketplace source refresh after merge**

Use the existing bstack release or Baleen Marketplace refresh flow. Do not edit generated snapshots. Verify the refreshed catalog has no matching plugin names.
