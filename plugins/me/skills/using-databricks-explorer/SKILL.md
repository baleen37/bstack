---
name: using-databricks-explorer
description: Use when a user asks to browse Databricks Unity Catalog or inspect a table using targets like <catalog>, <catalog>.<schema>, or <catalog>.<schema>.<table>.
---

# Using Databricks Explorer

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
| `<catalog>.<schema>.<table>` | `DESCRIBE TABLE c.s.t` → `DESCRIBE DETAIL c.s.t` → `SELECT * FROM c.s.t LIMIT 10` |

Always backtick-quote identifiers.

## Warehouse Resolution

1. If profile has `warehouse_id` → use it
2. Otherwise: `databricks warehouses list --output json --profile <name>` → pick first `RUNNING` warehouse

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
- rows: `result.data_array`
- error: `status.error.message` when `status.state == "FAILED"`

## Profile Selection

Read `~/.databrickscfg` (INI format). Default profile is `DEFAULT`.

If user specifies a profile (e.g. "use profile alpha"), pass `--profile alpha` to all commands.

If profile does not exist, list available profiles:

```bash
grep '^\[' ~/.databrickscfg | tr -d '[]'
```

## Limit Rules

- `SELECT *` default limit: `10`
- Maximum limit: `1000`
- If user requests > 1000, explain the cap and ask whether to proceed with `1000`

## Common Mistakes

- Calling table-level SQL with a partial target (e.g. `catalog.schema` instead of fully qualified)
- Forgetting to backtick-quote identifiers with dots or special characters
- Using `LIMIT > 1000`
- Attempting write operations

## Example

User: `/databricks:explore main.sales.orders`

```bash
# 1. Resolve warehouse
databricks warehouses list --output json --profile default

# 2. DESCRIBE TABLE
databricks api post /api/2.0/sql/statements --profile default \
  --json '{"statement":"DESCRIBE TABLE `main`.`sales`.`orders`","warehouse_id":"wh-abc","wait_timeout":"30s"}'

# 3. DESCRIBE DETAIL
databricks api post /api/2.0/sql/statements --profile default \
  --json '{"statement":"DESCRIBE DETAIL `main`.`sales`.`orders`","warehouse_id":"wh-abc","wait_timeout":"30s"}'

# 4. Preview
databricks api post /api/2.0/sql/statements --profile default \
  --json '{"statement":"SELECT * FROM `main`.`sales`.`orders` LIMIT 10","warehouse_id":"wh-abc","wait_timeout":"30s"}'
```

Return a concise summary of columns, key metadata, and sample rows.
