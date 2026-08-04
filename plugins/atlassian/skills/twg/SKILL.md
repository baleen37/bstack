---
name: twg
description: Route Jira work through the official Atlassian Teamwork Graph CLI.
---

# twg

Use the official `twg` CLI for Jira work. This plugin is intentionally MCP-free and Jira-only.

## Setup

```bash
bash <(curl -fsSL https://teamwork-graph.atlassian.com/cli/install)
twg login
twg setup
twg --version
```

Setup, login, logout, install, update, and credential commands are allowed only for explicit setup, authentication, or repair requests. For normal work, run read-only commands and report missing authentication rather than repairing it automatically.

## Command discovery

```bash
twg help
twg help describe "jira workitem get"
```

Use `twg help describe "<command path>"` before relying on unfamiliar or consequential command grammar.

## Jira routing

Load `twg-jira` when Jira is the source of truth.
