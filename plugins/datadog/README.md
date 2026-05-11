# datadog

Datadog observability skills for Claude Code, powered by the [`pup`](https://github.com/DataDog/pup) CLI.

## Prerequisites

Install `pup`:

```bash
brew tap datadog-labs/pack && brew install datadog-labs/pack/pup
```

Other install options (cargo, prebuilt binaries) are documented at https://github.com/DataDog/pup.

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

## Included Skills

| Skill | Purpose |
|---|---|
| `dd-pup` | Core pup CLI auth, command structure, output formats |
| `dd-logs` | Log search, pipelines, archives, cost control |
| `dd-monitors` | Monitor create/update/mute, alerting best practices |
| `dd-apm` | APM traces, services, dependencies, performance |
| `dd-docs` | Datadog docs lookup via `docs.datadoghq.com/llms.txt` |

## Upstream

Skill bodies are mirrored verbatim from [`DataDog/pup`](https://github.com/DataDog/pup) (`skills/` directory). Only the frontmatter is adjusted to match bstack's `name` + `description` convention. See `SYNC.md` for the upstream commit SHA and re-sync procedure.
