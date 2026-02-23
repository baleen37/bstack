---
name: databricks:explore
description: Explore Databricks Unity Catalog schema with SQL explorer tools
argument-hint: [<catalog|catalog.schema|catalog.schema.table>]
---

# Databricks SQL Schema Explorer

Use the `using-databricks-explorer` skill to handle this request.

Parse the argument (if any) as a drill-down target:

- *(no argument)* → list catalogs
- `<catalog>` → list schemas
- `<catalog>.<schema>` → list tables
- `<catalog>.<schema>.<table>` → describe table, show metadata, preview data
