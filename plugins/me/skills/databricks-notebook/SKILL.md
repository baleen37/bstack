---
name: databricks-notebook
description: Use when a user wants to run, test, or debug PySpark or Databricks code interactively without waiting for a full job run. Triggered by phrases like "run this code on Databricks", "test this PySpark snippet", "debug on cluster", "try this in a notebook", or "run as notebook".
---

# Databricks Notebook

## Overview

Run arbitrary PySpark/Databricks code on a job cluster by wrapping it in a
temporary notebook, uploading it to the workspace, and submitting a one-time
run via `databricks jobs submit`. This is for fast iteration during debugging
and exploration — not for scheduled jobs or production workloads.

**Do not use** `databricks-search` for this — that skill runs SQL via
the Statements API. This skill runs Python/PySpark code via `jobs submit` with
a `notebook_task` on a job cluster.

## Prerequisites

- `databricks` CLI installed (`brew install databricks`)
- `~/.databrickscfg` configured with at least one profile

## Profile Configuration

Read `~/.databrickscfg` (INI format). Use the `default` profile unless the
user specifies one.

List available profiles if needed:

```bash
grep '^\[' ~/.databrickscfg | tr -d '[]'
```

**Custom keys used by this skill** (added by the user; not standard Databricks fields):

| Key | Required | Description |
| --- | -------- | ----------- |
| `node_type_id` | Yes | Instance type for the job cluster (e.g. `i3.xlarge`) |
| `spark_version` | No | Databricks Runtime version (default: `15.4.x-scala2.12`) |
| `whl_path` | No | DBFS or Volumes path to a `.whl` to install on the cluster |
| `extra_index_url` | No | Private PyPI index URL for `pip` installs |

Read all four values at once with Python's `configparser`:

```bash
python3 - <<'EOF'
import configparser, os, sys
cfg = configparser.ConfigParser()
cfg.read(os.path.expanduser("~/.databrickscfg"))
profile = "default"  # replace with actual profile name
if profile not in cfg:
    print(f"ERROR: profile '{profile}' not found", file=sys.stderr)
    print("Available:", ", ".join(cfg.sections()), file=sys.stderr)
    sys.exit(1)
s = cfg[profile]
print("node_type_id:", s.get("node_type_id", ""))
print("spark_version:", s.get("spark_version", "15.4.x-scala2.12"))
print("whl_path:", s.get("whl_path", ""))
print("extra_index_url:", s.get("extra_index_url", ""))
EOF
```

If `node_type_id` is absent, stop and ask the user to add it to
`~/.databrickscfg`. Do not invent or default the instance type — it varies by
cloud provider and workspace region.

If `spark_version` is absent, use `15.4.x-scala2.12` as the default. If the
user mentions a version requirement, use that instead. To list available LTS
runtimes:

```bash
databricks api get /api/2.0/clusters/spark-versions --profile <profile> \
  | python3 -c "
import json, sys
for v in json.load(sys.stdin).get('versions', []):
    if 'LTS' in v.get('name', ''):
        print(v['key'], '-', v['name'])
" | head -10
```

## Workflow

```
1. READ    — read profile config (node_type_id, spark_version, whl_path, extra_index_url)
2. WRITE   — write user code as a temporary .py notebook file
3. UPLOAD  — import file to workspace (SOURCE format, PYTHON language)
4. SUBMIT  — one-time run via jobs submit with notebook_task + new_cluster
5. POLL    — wait for TERMINATED or SKIPPED state
6. OUTPUT  — fetch and display run output or error trace
7. CLEAN   — delete temporary notebook from workspace
```

## Step 1: Read Profile Config

Read config before building the payload. Stop if `node_type_id` is empty.

```bash
python3 - <<'EOF'
import configparser, os, sys
cfg = configparser.ConfigParser()
cfg.read(os.path.expanduser("~/.databrickscfg"))
profile = "default"  # replace with actual profile
s = cfg[profile]
print("node_type_id:", s.get("node_type_id", ""))
print("spark_version:", s.get("spark_version", "15.4.x-scala2.12"))
print("whl_path:", s.get("whl_path", ""))
print("extra_index_url:", s.get("extra_index_url", ""))
EOF
```

## Step 2: Write the Notebook File

Save user code to a local temp file as a Databricks SOURCE-format notebook.
The cell delimiter is `# COMMAND ----------` on its own line.

```bash
TMPFILE=$(mktemp /tmp/claude_nb_XXXXXX.py)
cat > "$TMPFILE" << 'PYEOF'
# Databricks notebook source
# COMMAND ----------

<user code here>

# COMMAND ----------

dbutils.notebook.exit(str(result))
PYEOF
```

Rules:
- `spark` is already available in notebook context — do not add `SparkSession.builder`.
- Always append `dbutils.notebook.exit(str(result))` so the output is
  retrievable via `get-run-output`. If the user code already calls it, keep theirs.
- `print()` output is **not** captured in `notebook_output.result` on success.
  Wrap the value the user cares about in `dbutils.notebook.exit()`.

## Step 3: Upload to Workspace

Use a timestamped path under `/tmp/` to avoid collisions with real notebooks:

```bash
TIMESTAMP=$(date +%s)
NOTEBOOK_PATH="/tmp/claude-nb-${TIMESTAMP}"

databricks workspace mkdirs /tmp --profile "${PROFILE}"
databricks workspace import "${NOTEBOOK_PATH}" \
  --profile "${PROFILE}" \
  --file "$TMPFILE" \
  --format SOURCE \
  --language PYTHON \
  --overwrite
```

`--overwrite` prevents `RESOURCE_ALREADY_EXISTS` errors on retries.

## Step 4: Submit a One-Time Run

Always use `--no-wait` and poll manually (Step 5). Build the JSON payload in
Python to avoid shell quoting issues, then submit:

```bash
PAYLOAD=$(python3 - <<EOF
import json

cluster = {
    "spark_version": "${SPARK_VER}",
    "node_type_id": "${NODE_TYPE}",
    "num_workers": 1,
}
if "${EXTRA_INDEX}":
    cluster["spark_env_vars"] = {"PIP_EXTRA_INDEX_URL": "${EXTRA_INDEX}"}

task = {
    "task_key": "main",
    "notebook_task": {
        "notebook_path": "${NOTEBOOK_PATH}",
        "source": "WORKSPACE",
    },
    "new_cluster": cluster,
}
if "${WHL_PATH}":
    task["libraries"] = [{"whl": "${WHL_PATH}"}]

print(json.dumps({"run_name": "claude-nb-run", "tasks": [task]}))
EOF
)

RUN_ID=$(databricks jobs submit \
  --profile "${PROFILE}" \
  --no-wait \
  --output json \
  --json "$PAYLOAD" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['run_id'])")

echo "Run ID: ${RUN_ID}"
```

**API notes:**
- `tasks` array is required by Jobs API v2.1, even for single-task runs.
- `"source": "WORKSPACE"` is required in `notebook_task`; omitting it can
  cause Databricks to mis-resolve the path as a Repos path.
- `PIP_EXTRA_INDEX_URL` via `spark_env_vars` makes it available to `pip`
  during cluster library installation.

## Step 5: Poll for Completion

```bash
while true; do
  POLL=$(databricks jobs get-run "${RUN_ID}" --profile "${PROFILE}" --output json \
    | python3 -c "
import json, sys
r = json.load(sys.stdin)
lc = r['state']['life_cycle_state']
rs = r['state'].get('result_state', '')
print(lc, rs)
")
  LC=$(echo "$POLL" | cut -d' ' -f1)
  RS=$(echo "$POLL" | cut -d' ' -f2)
  echo "  state: $LC $RS"
  [ "$LC" = "TERMINATED" ] || [ "$LC" = "SKIPPED" ] && break
  sleep 10
done
```

After the loop, check `RS`:
- `SUCCESS` → proceed to Step 6
- `FAILED` → proceed to Step 6 (error details are in the output)
- `TIMEDOUT` → inform user; cancel with `databricks jobs cancel-run "${RUN_ID}" --profile "${PROFILE}"`
- `CANCELED` → inform user the run was canceled externally

## Step 6: Fetch and Display Output

```bash
databricks jobs get-run-output "${RUN_ID}" --profile "${PROFILE}" --output json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
nb = d.get('notebook_output', {}).get('result', '')
error = d.get('error', '')
error_trace = d.get('error_trace', '')

if nb:
    print('Result:', nb)
else:
    print('(no notebook_output.result — add dbutils.notebook.exit(str(value)) to capture output)')
if error:
    print('Error:', error)
if error_trace:
    print('--- Traceback ---')
    print(error_trace)
"
```

**Output field map:**

| Field | Contains |
| ----- | -------- |
| `notebook_output.result` | Value passed to `dbutils.notebook.exit()` (max 5 MB) |
| `error` | One-line error summary (present when `result_state == FAILED`) |
| `error_trace` | Full Python/JVM traceback — always show on failure, never truncate |

## Step 7: Clean Up

Always delete the temporary notebook and local temp file, even if the run failed:

```bash
databricks workspace delete "${NOTEBOOK_PATH}" --profile "${PROFILE}"
rm -f "$TMPFILE"
```

## Error Handling Reference

| Symptom | Likely cause | Action |
| ------- | ------------ | ------ |
| `result_state == "FAILED"` with `ModuleNotFoundError` | `whl_path` missing or wrong | Verify path exists; check profile config |
| `RESOURCE_ALREADY_EXISTS` on import | Path collision | Already handled by `--overwrite` |
| `INVALID_PARAMETER_VALUE` on submit | Bad `spark_version` or `node_type_id` | List available versions/types (see Prerequisites) |
| Cluster launch error in `error_trace` | Node type unavailable in region | Ask user to pick an available node type |
| `result_state == "TIMEDOUT"` | Code ran past cluster timeout | Cancel run; reduce data size or add timeout config |
| `notebook_output.result` empty on success | No `dbutils.notebook.exit()` call | Advise user to add exit call |
| Run not visible in Jobs UI | Expected — one-time submit runs are ephemeral | Use `jobs get-run` to check status |

## Complete Example

User: "Run this on Databricks and show me the output: `df = spark.table('main.sales.orders'); print(df.count())`"

```bash
PROFILE="default"

# 1. Read config
NODE_TYPE=$(python3 -c "
import configparser, os
cfg = configparser.ConfigParser()
cfg.read(os.path.expanduser('~/.databrickscfg'))
print(cfg['${PROFILE}'].get('node_type_id', ''))
")
SPARK_VER=$(python3 -c "
import configparser, os
cfg = configparser.ConfigParser()
cfg.read(os.path.expanduser('~/.databrickscfg'))
print(cfg['${PROFILE}'].get('spark_version', '15.4.x-scala2.12'))
")
WHL_PATH=$(python3 -c "
import configparser, os
cfg = configparser.ConfigParser()
cfg.read(os.path.expanduser('~/.databrickscfg'))
print(cfg['${PROFILE}'].get('whl_path', ''))
")

# 2. Write notebook
TMPFILE=$(mktemp /tmp/claude_nb_XXXXXX.py)
cat > "$TMPFILE" << 'PYEOF'
# Databricks notebook source
# COMMAND ----------

df = spark.table('main.sales.orders')
result = df.count()
dbutils.notebook.exit(str(result))
PYEOF

# 3. Upload
TIMESTAMP=$(date +%s)
NOTEBOOK_PATH="/tmp/claude-nb-${TIMESTAMP}"
databricks workspace mkdirs /tmp --profile "${PROFILE}"
databricks workspace import "${NOTEBOOK_PATH}" \
  --profile "${PROFILE}" \
  --file "$TMPFILE" \
  --format SOURCE \
  --language PYTHON \
  --overwrite

# 4. Build payload and submit
PAYLOAD=$(python3 - <<EOF
import json
cluster = {"spark_version": "${SPARK_VER}", "node_type_id": "${NODE_TYPE}", "num_workers": 1}
task = {
    "task_key": "main",
    "notebook_task": {"notebook_path": "${NOTEBOOK_PATH}", "source": "WORKSPACE"},
    "new_cluster": cluster,
}
if "${WHL_PATH}":
    task["libraries"] = [{"whl": "${WHL_PATH}"}]
print(json.dumps({"run_name": "claude-nb-run", "tasks": [task]}))
EOF
)

RUN_ID=$(databricks jobs submit \
  --profile "${PROFILE}" \
  --no-wait \
  --output json \
  --json "$PAYLOAD" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['run_id'])")
echo "Run ID: ${RUN_ID}"

# 5. Poll
while true; do
  POLL=$(databricks jobs get-run "${RUN_ID}" --profile "${PROFILE}" --output json \
    | python3 -c "import json,sys; r=json.load(sys.stdin); print(r['state']['life_cycle_state'], r['state'].get('result_state',''))")
  LC=$(echo "$POLL" | cut -d' ' -f1)
  echo "  state: $POLL"
  [ "$LC" = "TERMINATED" ] || [ "$LC" = "SKIPPED" ] && break
  sleep 10
done

# 6. Output
databricks jobs get-run-output "${RUN_ID}" --profile "${PROFILE}" --output json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
nb = d.get('notebook_output', {}).get('result', '')
err = d.get('error', '')
tr = d.get('error_trace', '')
if nb: print('Result:', nb)
else: print('(no output — add dbutils.notebook.exit() to capture result)')
if err: print('Error:', err)
if tr: print('--- Traceback ---'); print(tr)
"

# 7. Clean up
databricks workspace delete "${NOTEBOOK_PATH}" --profile "${PROFILE}"
rm -f "$TMPFILE"
```

## Relationship to Other Skills

| Skill | Use for |
| ----- | ------- |
| `databricks-search` | Read-only SQL: list catalogs, describe tables, preview rows |
| `databricks-notebook` | Execute PySpark/Python code on a real cluster |

Never use `databricks-search` for code execution, and never use this
skill for catalog/schema browsing (it would waste cluster startup time).
