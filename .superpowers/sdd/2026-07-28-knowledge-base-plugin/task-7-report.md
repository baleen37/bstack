# Task 7: knowledge-base plugin and Codex artifacts

## Status

Completed. The `knowledge-base` Claude plugin is installable with a local stdio MCP launcher, a
retrieval-only skill, generated Codex artifacts, and structural regression coverage.

## Plan conflict and resolution

The brief's Claude manifest intentionally has no Codex `interface` object. Initially,
`plugin-creator/scripts/validate_plugin.py` rejected the generated Codex manifest with
`plugin.json field interface must be an object`. The user resolved the conflict by making the
current Codex contract authoritative: Claude manifests remain source metadata, while the Codex
generator deterministically adds the required `interface` to every generated skill-plugin
manifest.

## Implementation

- Appended the `knowledge-base` entry to the Claude marketplace without reordering existing entries.
- Added the exact Claude metadata source, local `sh -lc` MCP launcher, and retrieval-only skill.
- Added `knowledge-base` to official MCP manifest coverage plus local-MCP/no-query-expansion/no-rerank
  coverage. Negative grep assertions use BATS-safe captured exit statuses.
- Extended `generate-codex-plugin-manifests.sh` to derive Codex interface fields from Claude source:
  title-cased display name, description-derived short/long descriptions, author name, `Productivity`,
  `Skills` plus conditional `MCP` capabilities, and one bounded deterministic default prompt.
- Added BATS assertions for every generated interface, capabilities, and prompt. Regenerated all
  Codex manifests with `bun run sync:codex`; none was hand-edited.

## Source and generated relationship

- Source: `.claude-plugin/marketplace.json` and each
  `plugins/*/.claude-plugin/plugin.json`.
- Generator: `scripts/generate-codex-plugin-manifests.sh` derives
  `plugins/*/.codex-plugin/plugin.json`; `scripts/generate-codex-marketplace.sh` derives
  `.agents/plugins/marketplace.json`.
- Drift guard: `bun run check:codex` reruns both generators and requires no unstaged generated drift.

## RED and GREEN evidence

- RED: `bats tests/codex_plugin_json.bats tests/knowledge-base/knowledge-base-specific.bats`
  failed the new interface test because pre-existing generated manifests had no `.interface`.
- GREEN: the same command passed all 11 tests after the generator update and regeneration.
- GREEN: `bash tests/run-all-tests.sh` passed (66 root tests plus all integration/plugin suites).
- GREEN: `bun run check:codex` passed after staging regenerated artifacts.
- GREEN: in `plugins/knowledge-base`, `bun run build`, `bun run typecheck`, and `bun run test`
  passed; Vitest reported 9 files and 86 tests passing.
- GREEN: `uv run --with pyyaml python .../validate_plugin.py` passed for all seven generated
  skill plugins, including `knowledge-base`; `quick_validate.py` reported `Skill is valid!`.

## Files

- New source/plugin files: `plugins/knowledge-base/.claude-plugin/plugin.json`, `.mcp.json`, and
  `skills/knowledge-base/SKILL.md`.
- Generated: `plugins/knowledge-base/.codex-plugin/plugin.json`,
  `.agents/plugins/marketplace.json`, and regenerated Codex manifests for me, jira, slack, notion,
  datadog, and autoresearch.
- Tests/generator: `tests/official_mcp_plugins.bats`,
  `tests/knowledge-base/knowledge-base-specific.bats`, `tests/codex_plugin_json.bats`, and
  `scripts/generate-codex-plugin-manifests.sh`.

## Self-review and concerns

- The launcher executes only `${KNOWLEDGE_BASE_BIN:-knowledge-base} mcp` through `exec`; it does not
  install packages or emit wrapper output to stdout.
- The skill only guides read-only `status`, `search`, and `get`; it treats scope as a search filter,
  not authorization, and forbids document edits, commits, and pushes.
- `pre-commit run --all-files` remains non-green due to pre-existing repository-wide ShellCheck and
  markdownlint violations. Its only automatic change, a final newline in
  `plugins/me/skills/setup/CLAUDE.md`, was reverted. New/changed Task 7 files introduced no reported
  ShellCheck or markdownlint finding.

## Fix round 1

- Hardened the local stdio launcher test to require the exact two-element argument array
  `[-lc, exec "${KNOWLEDGE_BASE_BIN:-knowledge-base}" mcp]` and reject `npx`, `bunx`, npm install,
  and bun install tokens anywhere in its arguments.
- Replaced presence-only Codex interface checks with source-derived equality checks for title-cased
  display name, both descriptions, developer name, exact capabilities, category, and the bounded
  one-item default prompt. The assertion derives the display name independently with portable `awk`
  rather than copying the generator's jq implementation.
- This was a test-gap fix: the existing launcher and generator already met the strengthened
  contracts. The first test invocation exposed an `awk` test-authoring error (reserved `index`
  identifier), not a product failure; after renaming it to `part`, targeted BATS passed 11/11.
- Reverification: root suite passed (66 root tests plus all plugin/integration suites), sync/check
  passed, and plugin plus skill validators passed.
