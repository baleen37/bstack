# datadog

Datadog observability guidance powered by the [`pup`](https://github.com/DataDog/pup) CLI.

This plugin intentionally does not configure a Datadog MCP server.

## Prerequisites

Install `pup`:

```bash
brew tap datadog-labs/pack && brew install datadog-labs/pack/pup
```

Other install options (cargo, prebuilt binaries) are documented at <https://github.com/DataDog/pup>.

## Authentication

Recommended — OAuth2 (browser-based, secure token storage):

```bash
pup auth login
```

Alternative — API key via environment variables:

```bash
export DD_API_KEY=...
export DD_APP_KEY=...
export DD_SITE=datadoghq.com   # or datadoghq.eu, etc.
```

## Included Skill

- `datadog`: logs, monitors, APM, metrics, and incident investigation via `pup`.
