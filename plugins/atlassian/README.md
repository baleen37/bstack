# atlassian

Jira work guidance powered by the official [Atlassian Teamwork Graph CLI](https://github.com/atlassian/twg-cli).

This plugin is intentionally Jira-only and MCP-free.

## Installation

Install the official CLI, then authenticate and select its local setup:

```bash
bash <(curl -fsSL https://teamwork-graph.atlassian.com/cli/install)
twg login
twg setup
twg --version
```

## Authentication boundary

Run installation, login, setup, logout, update, or credential commands only for an explicit setup, authentication, or repair request. For ordinary Jira work, use read-only commands and report missing authentication instead of changing credentials automatically.

## Scope and included skills

The plugin covers Jira work through `twg`; it does not provide Confluence or other Atlassian product guidance.

- `twg`: command discovery, setup/authentication boundary, and Jira routing.
- `twg-jira`: Jira search, reads, and safe mutation guidance.
