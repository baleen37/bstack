---
name: opensearch
description: This skill should be used when the user asks to "connect to OpenSearch", "query OpenSearch", "manage OpenSearch indices", "troubleshoot OpenSearch", or mentions OpenSearch connection, index management, or OpenSearch API access.
version: 0.1.0
---

# OpenSearch

## Overview

Connect to, query, and manage OpenSearch using `curl`.

## Common APIs

| API Path | Description |
|----------|-------------|
| `/_cluster/health` | Cluster health status |
| `/_cat/indices?v` | List all indices |
| `/<index>/_search` | Search in index |
| `/<index>/_doc/<id>` | Get document by ID |
| `/<index>/_mapping` | Get index mapping |

## Examples

```bash
# Health check (Basic Auth)
curl -u username:password https://your-domain:9200/_cluster/health?pretty

# Search
curl -u username:password \
  -H 'Content-Type: application/json' \
  -d '{"query": {"match_all": {}}, "size": 10}' \
  https://your-domain:9200/your-index/_search?pretty

# Delete index
curl -u username:password -X DELETE https://your-domain:9200/your-index
```

## Resources

- **`references/`** - Detailed guides for index management, queries, troubleshooting
- **`examples/`** - Common operation scripts
- **`scripts/health-check.sh`** - Cluster diagnostics
- [OpenSearch REST API](https://docs.opensearch.org/latest/api-reference/index.html)
