---
name: datadog
description: Use the Datadog pup CLI for logs, monitors, APM, metrics, and incident investigation.
---

# Datadog

Use the `pup` CLI. This plugin intentionally does not configure a Datadog MCP server.

## Setup

```bash
pup auth login
```

Environment-variable auth is also supported when OAuth is not available:

```bash
export DD_API_KEY=...
export DD_APP_KEY=...
export DD_SITE=datadoghq.com
```

## Workflow

1. Check authentication with `pup auth status` or a small read-only command.
2. Start investigations with a narrow time window, service, environment, and signal type.
3. Prefer JSON output when results need to be filtered or cited.
4. For logs, search exact error signatures first, then broaden to service and status.
5. For monitors or incidents, inspect current state before suggesting updates.

## Command Discovery

```bash
pup --help
pup logs --help
pup monitors --help
pup apm --help
```

## Essential Patterns

- Logs: use exact error text, `service`, `env`, and a short time window first.
- Monitors: inspect current alert state and history before proposing changes.
- APM: compare latency, error rate, and throughput for the same service and environment.
- Metrics: state the query, rollup, group-by, and time window with the result.
- Incidents: collect timeline, impacted services, active monitors, and owner before summarizing.

## Safety

- Avoid dumping high-volume logs into the conversation.
- Redact tokens, customer identifiers, and sensitive attributes.
- State the exact time range, query, and command used for evidence.
