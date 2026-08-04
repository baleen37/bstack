# bstack collaboration plugin removal

## Goal

Remove the bstack-owned Jira, Notion, and Slack plugins from local Claude and
Codex installations, the bstack source marketplace, and its generated Codex
artifacts.

## Scope

- Uninstall only `jira@baleen-marketplace`, `notion@baleen-marketplace`, and
  `slack@baleen-marketplace` where they are installed.
- Delete `plugins/jira`, `plugins/notion`, and `plugins/slack`.
- Remove those three entries from `.claude-plugin/marketplace.json`.
- Remove tests and test-runner registrations whose only purpose is the deleted
  plugins.
- Regenerate and verify the checked-in Codex plugin artifacts.

## Boundaries

- Keep third-party Slack plugins, including `slack@openai-curated` and
  `slack@claude-plugins-official`.
- Keep the Baleen Marketplace source registration for bstack. It uses the
  generic `plugins/*` path, so it has no per-plugin entry to delete. Its next
  source refresh will stop publishing the removed plugins.
- Do not edit generated local marketplace snapshots or caches.

## Verification

1. Claude and Codex plugin lists no longer show the bstack plugin ids as
   installed.
2. The marketplace manifest contains no `jira`, `notion`, or `slack` entry.
3. No remaining repository reference points at their deleted source paths.
4. `npm run sync:codex`, `npm run check:codex`, and the relevant test suite
   pass.
