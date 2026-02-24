---
name: databricks-search
description: Use when a user asks to browse Databricks Unity Catalog, list schemas or tables, or inspect table columns and sample data.
---

# Databricks Search

## Overview

Explore Databricks Unity Catalog by running `databricks` CLI commands directly via Bash.
Interpret the target shape, then execute the appropriate SQL using the Statements API.

## Prerequisites

- `databricks` CLI installed (`brew install databricks`)
- `~/.databrickscfg` configured with at least one profile

## When to Use

- list catalogs, schemas, or tables in Unity Catalog
- inspect table columns and metadata
- preview sample rows from a specific table

Do not use for write operations (`INSERT`, `UPDATE`, `DELETE`, `CREATE`, `DROP`) or bulk export.

## Target → SQL Mapping

| User target | SQL |
| --- | --- |
| *(no target)* | `SHOW CATALOGS` |
| `<catalog>` | `SHOW SCHEMAS IN \`catalog\`` |
| `<catalog>.<schema>` | `SHOW TABLES IN \`catalog\`.\`schema\`` |
| `<catalog>.<schema>.<table>` | `DESCRIBE TABLE c.s.t` → `SELECT * FROM c.s.t LIMIT 10` |

Always backtick-quote identifiers.

## Warehouse Resolution

1. If profile has `warehouse_id` → use it
2. Otherwise: `databricks api get /api/2.0/sql/warehouses --profile <name>` → pick first `RUNNING` warehouse

## Executing SQL

```bash
databricks api post /api/2.0/sql/statements \
  --profile <profile> \
  --json '{
    "statement": "<SQL>",
    "warehouse_id": "<warehouse_id>",
    "wait_timeout": "30s"
  }'
```

Parse result from:

- columns: `manifest.schema.columns[].name`, `manifest.schema.columns[].type_name`
- rows: `result.data_array` — **absent (not empty list) when zero rows returned**; always use `.get('data_array', [])`
- error: `status.error.message` when `status.state == "FAILED"`

## Token Efficiency Rules

`--output text|json` CLI flags have **no effect** on `api post` — always returns JSON. Use jq post-processing.

TSV is the most token-efficient output format (~90% smaller than raw JSON).

### Default: TSV (best for LLM readability)

```bash
databricks api post /api/2.0/sql/statements --profile <profile> \
  --json '{"statement":"<SQL>","warehouse_id":"<warehouse_id>","wait_timeout":"30s"}' \
  | jq -r '([.manifest.schema.columns[].name] | @tsv), (.result.data_array[:10][] | @tsv)'
```

Output looks like:

```text
source          cnt
products.image  634520
products.text   282054
```

### Rules

- Always slice rows: `[:10]` default, never load full array — row slicing is the biggest savings for large result sets
- Never use raw JSON — `statement_id`, `chunk_index`, `type_text` metadata wastes 80%+ of tokens
- For wide tables: `DESCRIBE TABLE` first, then `SELECT col1, col2` instead of `SELECT *`

## Profile Selection

Read `~/.databrickscfg` (INI format). Default profile is `DEFAULT` (case-insensitive).

If user specifies a profile (e.g. "use profile alpha"), pass `--profile alpha` to all commands.

If profile does not exist, list available profiles:

```bash
grep '^\[' ~/.databrickscfg | tr -d '[]'
```

## Limit Rules

- `SELECT *` default limit: `10` (matches row slice in jq output)
- Maximum limit: `1000`
- If user requests > 1000, explain the cap and ask whether to proceed with `1000`

## Common Mistakes

- Calling table-level SQL with a partial target (e.g. `catalog.schema` instead of fully qualified)
- Forgetting to backtick-quote identifiers with dots or special characters
- Using `LIMIT > 1000`
- Attempting write operations
- Accessing `result.data_array` directly — key is absent when zero rows returned, not an empty list

## Example

User: `/me:databricks.explore main.sales.orders`

```bash
# 1. Resolve warehouse
databricks api get /api/2.0/sql/warehouses --profile default | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data.get('warehouses', []):
    if w['state'] == 'RUNNING':
        print(w['id'])
        break
"

# 2. DESCRIBE TABLE
databricks api post /api/2.0/sql/statements --profile default \
  --json '{"statement":"DESCRIBE TABLE `main`.`sales`.`orders`","warehouse_id":"wh-abc","wait_timeout":"30s"}' \
  | jq -r '([.manifest.schema.columns[].name] | @tsv), (.result.data_array[:10][] | @tsv)'

# 3. Preview
databricks api post /api/2.0/sql/statements --profile default \
  --json '{"statement":"SELECT * FROM `main`.`sales`.`orders` LIMIT 10","warehouse_id":"wh-abc","wait_timeout":"30s"}' \
  | jq -r '([.manifest.schema.columns[].name] | @tsv), (.result.data_array[:10][] | @tsv)'
```

Return a concise summary of columns, key metadata, and sample rows.
