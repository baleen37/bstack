# Notion and Jira CLI Plugins Design

## Status

Approved on 2026-08-03.

## Goal

Add two CLI-only marketplace plugins to bstack:

- `notion`, backed by the official `ntn` Notion CLI.
- `atlassian`, backed by the official `twg` CLI and limited to Jira workflows.

The plugins provide agent guidance for installation, authentication, command discovery, safe reads, and supported writes. They do not configure MCP servers or run authentication automatically.

## Scope

### Notion plugin

Create `plugins/notion` with one `notion` skill covering:

- installation and version checks;
- browser, headless, and PAT authentication paths;
- workspace selection and session diagnostics;
- `ntn api` request/body/query syntax;
- file upload basics;
- redaction and verbose-output safety.

The skill will use the official Notion CLI documentation as its source:
`https://developers.notion.com/cli/get-started/overview`.

### Atlassian plugin

Create `plugins/atlassian` with:

- a `twg` root skill for command discovery and authentication/setup boundaries;
- a `twg-jira` skill for Jira work-item search, query, get, create, comment, update, and transition guidance.

Jira routing will distinguish:

- `twg jira workitem search` for Jira-only fuzzy text discovery;
- `twg jira workitem query --jql` for explicit JQL;
- `twg search "topic" --app jira` for semantic cross-product discovery;
- `twg jira workitem get` for final details on known work items.

The skill will follow the public upstream guidance from `https://github.com/atlassian/twg-cli` and defer unfamiliar command grammar to live `twg help` or `twg help describe` output.

## Package shape

Each plugin will follow the repository source-of-truth convention:

```text
plugins/notion/
├── .claude-plugin/plugin.json
├── README.md
└── skills/notion/SKILL.md

plugins/atlassian/
├── .claude-plugin/plugin.json
├── README.md
└── skills/
    ├── twg/SKILL.md
    └── twg-jira/SKILL.md
```

The manifests will use the current bstack release version and will not contain `mcpServers`. The generated `.codex-plugin/plugin.json` files and `.agents/plugins/marketplace.json` will be regenerated from the Claude source manifests.

The root marketplace and README plugin listings will include both plugins. No retired Slack/Jira/Notion source will be restored.

## Safety and behavior

- Never run `ntn login`, `ntn logout`, `twg login`, `twg logout`, `twg setup`, install, update, or credential commands unless the user explicitly requests setup or repair.
- Read current Jira state before any mutation.
- Discover fields and transitions with the CLI help or product-native metadata before writes.
- Require explicit confirmation for Jira creates and other consequential mutations, using the CLI's advertised confirmation option.
- Prefer compact, bounded output and JSON only when filtering or machine-readable evidence is needed.
- Do not include tokens, private URLs, workspace data, or local absolute paths in plugin files.

## Verification

Add a lightweight BATS contract covering:

- both plugin directories and manifests are present;
- both plugins are listed in `.claude-plugin/marketplace.json`;
- both CLI plugins have skills and no MCP configuration;
- the Notion skill names `ntn` and the Atlassian skills name `twg` and Jira routing commands.

Run the repository checks:

```bash
bun run sync:codex
bun run check:codex
bun run test
git diff --check
```

Success means all checks pass, generated artifacts are clean, manifests have no MCP server entries, and the diff contains only the two requested CLI plugins plus their marketplace, README, test, and generated-artifact updates.
