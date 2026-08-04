# Task 3 Report: Jira-only Atlassian CLI plugin

## Status

PASS

## Scope

Implemented only the Atlassian plugin source required by Task 3:

- `plugins/atlassian/.claude-plugin/plugin.json`
- `plugins/atlassian/README.md`
- `plugins/atlassian/skills/twg/SKILL.md`
- `plugins/atlassian/skills/twg-jira/SKILL.md`

Marketplace metadata and the root README were not changed. No MCP configuration or `.mcp.json` file was added.

## Implementation

- Added the 17.41.1 `atlassian` manifest with the official `twg` repository as its homepage.
- Added the Jira-only, MCP-free README with official installation, login, setup, version-check, and explicit-auth boundaries.
- Added root `twg` guidance for setup, command discovery, and Jira routing.
- Added `twg-jira` routing for fuzzy search, JQL, semantic search, native issue reads, create, and comments.
- Documented positional issue keys, `twg help describe` command discovery, native reads for final fields and URLs, and pre-mutation state/metadata/transition checks.

## Installed CLI evidence

- CLI metadata: `twg 1.1.1`
- Live `twg help describe` confirmed these command paths: `jira workitem get`, `jira workitem search`, `jira workitem query`, `jira workitem create`, `jira workitem comment create`, and `jira workitem comment update`.
- `jira workitem get` reports its issue key as a positional argument.

## Validation

| Check | Result |
| --- | --- |
| `bats tests/frontmatter_tests.bats` | PASS, 3/3 |
| `bats tests/plugin_json.bats` | PASS, 9/9 |
| `git diff --check` | PASS |
| Manifest has no `mcpServers` entry and no `.mcp.json` exists | PASS |
| Required Task 3 command and routing text | PASS |
| Post-commit `git show --check` | PASS |

The aggregate `tests/cli_plugins.bats` contract was intentionally not run because Task 4 is responsible for registering both plugins in marketplace metadata.

## Self-review

- The diff contains only the four requested Atlassian source files.
- The root skill restricts setup, authentication, credential, install, logout, and update commands to explicit setup/auth/repair requests.
- The Jira skill requires current-state reads before create, update, comment, and transition; metadata or transition discovery before consequential writes; user-visible intent before `--yes`; and native readback after mutation.
- Neither the README nor either skill claims Confluence or other Atlassian-product coverage.

## Commit

`6b889366 feat(atlassian): add jira twg cli plugin`

## Concerns

None within Task 3 scope. Marketplace registration and the aggregate CLI contract remain intentionally deferred to Task 4.

## Review fix report

### Findings fixed

- Removed the local absolute CLI path. Installed CLI evidence now records only portable metadata: `twg 1.1.1`.
- Added `Output boundaries` to `plugins/atlassian/skills/twg-jira/SKILL.md`: searches and reads default to bounded human-readable output, result counts use `--limit` or an appropriate range, and `--output json` is reserved for filtering or machine-readable evidence.

### Changed files

- `plugins/atlassian/skills/twg-jira/SKILL.md`
- `.superpowers/sdd/2026-08-03-notion-and-jira-cli-plugins/task-3-report.md`

### Commands and actual output

```text
$ bats tests/frontmatter_tests.bats
1..3
ok 1 Agent files exist in plugins
ok 2 Agent files have frontmatter delimiter
ok 3 SKILL.md files exist

$ bats tests/plugin_json.bats
1..9
ok 1 all plugins have plugin.json
ok 2 all plugin.json files are valid JSON
ok 3 all plugin.json files have required fields
ok 4 all plugin.json names follow naming convention
ok 5 all plugin.json required fields are not empty
ok 6 all plugin.json files use only allowed fields
ok 7 all plugin.json files pass comprehensive validation
ok 8 plugin count is valid
ok 9 no invalid plugin manifests exist
```

### New commit

`fix(atlassian): bound twg output guidance`
