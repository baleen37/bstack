---
name: databricks-notebook
description: Use when a user wants to run, test, or debug a local Python/PySpark file on Databricks without waiting for a full job run. Requires a databricks.yml (DAB project). Triggered by phrases like "run this file on Databricks", "debug on cluster", "test this script", or "run as notebook".
---

# Databricks Notebook

## Overview

Run a local `.py` file on a Databricks job cluster by uploading it as a temporary
notebook and submitting a one-time run via `databricks jobs submit`. Service code
dependencies are handled by deploying the project whl via `bundle deploy` first.

**Requires a DAB project** (`databricks.yml` in the current directory). All cluster
config and whl paths are read from the bundle — never hardcoded.

**Do not use** `databricks-search` for this — that skill runs SQL via the Statements
API. This skill executes Python/PySpark code on a real cluster.

## Prerequisites

- `databricks` CLI installed (`brew install databricks`)
- `databricks.yml` present in the current directory (DAB project)
- `~/.databrickscfg` configured with the target profile

## Workflow

```
1. VALIDATE — bundle validate to extract cluster config and whl path
2. DEPLOY   — bundle deploy to build and upload the whl to workspace
3. UPLOAD   — import local .py file to workspace as a notebook
4. SUBMIT   — one-time run via jobs submit (cluster config + whl from step 1-2)
5. POLL     — wait for TERMINATED or SKIPPED state
6. OUTPUT   — fetch and display run output or error trace
7. CLEAN    — delete temporary notebook from workspace
```

## Step 1: Validate Bundle

Extract cluster config and artifact path from the bundle. Run once before deploying:

```bash
VALIDATE=$(databricks bundle validate --target <target> --output json)

# Cluster config — from first job's first cluster definition
SPARK_VER=$(echo "$VALIDATE" | python3 -c "
import json, sys
b = json.load(sys.stdin)
j = next(iter(b['resources']['jobs'].values()))
print(j['job_clusters'][0]['new_cluster']['spark_version'])
")
NODE_TYPE=$(echo "$VALIDATE" | python3 -c "
import json, sys
b = json.load(sys.stdin)
j = next(iter(b['resources']['jobs'].values()))
print(j['job_clusters'][0]['new_cluster']['node_type_id'])
")

# Artifact root path (whl will be placed here after deploy)
ARTIFACT_PATH=$(echo "$VALIDATE" | python3 -c "
import json, sys
print(json.load(sys.stdin)['workspace']['artifact_path'])
")
```

If `spark_version` or `node_type_id` is empty, the bundle may use a shared cluster
policy — check the job YAML directly or ask the user.

## Step 2: Deploy Bundle

Build the whl and upload it to `ARTIFACT_PATH`:

```bash
databricks bundle deploy --target <target>
```

After deploy, find the whl under the artifact path:

```bash
WHL_PATH=$(databricks fs ls "${ARTIFACT_PATH}" --profile <profile> \
  | grep '\.whl$' | head -1 | awk '{print $NF}')
echo "WHL_PATH: ${WHL_PATH}"
```

If `WHL_PATH` is empty, the bundle may not define a whl artifact — check `databricks.yml`.

## Step 3: Upload Local File as Notebook

Upload the local `.py` file to a timestamped path under `/tmp/` in the workspace:

```bash
TIMESTAMP=$(date +%s)
NOTEBOOK_PATH="/tmp/claude-nb-${TIMESTAMP}"

databricks workspace mkdirs /tmp --profile <profile>
databricks workspace import "${NOTEBOOK_PATH}" \
  --profile <profile> \
  --file <local-file.py> \
  --format SOURCE \
  --language PYTHON \
  --overwrite
```

**Notebook output capture:** `notebook_output.result` only captures the value passed
to `dbutils.notebook.exit()` — `print()` output is not captured on success.

If the file has no `dbutils.notebook.exit()` call, append a cell:

```python
# COMMAND ----------
dbutils.notebook.exit("done")
```

`spark` is already available in notebook context — do not add `SparkSession.builder`.

## Step 4: Submit One-Time Run

Build the payload in Python. Pass shell variables via environment to avoid quoting issues:

```bash
PAYLOAD=$(SPARK_VER="${SPARK_VER}" NODE_TYPE="${NODE_TYPE}" \
  NOTEBOOK_PATH="${NOTEBOOK_PATH}" WHL_PATH="${WHL_PATH}" \
  python3 - <<'EOF'
import json, os

cluster = {
    "spark_version": os.environ["SPARK_VER"],
    "node_type_id": os.environ["NODE_TYPE"],
    "num_workers": 1,
}

task = {
    "task_key": "main",
    "notebook_task": {
        "notebook_path": os.environ["NOTEBOOK_PATH"],
        "source": "WORKSPACE",
    },
    "new_cluster": cluster,
    "libraries": [{"whl": os.environ["WHL_PATH"]}],
}

print(json.dumps({"run_name": "claude-nb-run", "tasks": [task]}))
EOF
)

RUN_ID=$(databricks jobs submit \
  --profile <profile> \
  --no-wait \
  --output json \
  --json "$PAYLOAD" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['run_id'])")

echo "Run ID: ${RUN_ID}"
```

**API notes:**
- `tasks` array required by Jobs API v2.1, even for single-task runs.
- `"source": "WORKSPACE"` required — omitting it causes Repos path resolution errors.

## Step 5: Poll for Completion

```bash
while true; do
  POLL=$(databricks jobs get-run "${RUN_ID}" --profile <profile> --output json \
    | python3 -c "
import json, sys
r = json.load(sys.stdin)
print(r['state']['life_cycle_state'], r['state'].get('result_state', ''))
")
  LC=$(echo "$POLL" | cut -d' ' -f1)
  RS=$(echo "$POLL" | cut -d' ' -f2)
  echo "  state: $LC $RS"
  if [ "$LC" = "TERMINATED" ] || [ "$LC" = "SKIPPED" ]; then break; fi
  sleep 10
done
```

After the loop, check `RS`:
- `SUCCESS` → proceed to Step 6
- `FAILED` → proceed to Step 6 (error details in output)
- `TIMEDOUT` → cancel with `databricks jobs cancel-run "${RUN_ID}" --profile <profile>`
- `CANCELED` → inform user

## Step 6: Fetch and Display Output

```bash
databricks jobs get-run-output "${RUN_ID}" --profile <profile> --output json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
nb = d.get('notebook_output', {}).get('result', '')
error = d.get('error', '')
error_trace = d.get('error_trace', '')

if nb:
    print('Result:', nb)
else:
    print('(no output — add dbutils.notebook.exit(str(result)) to capture output)')
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
| `notebook_output.result` | Value from `dbutils.notebook.exit()` (max 5 MB) |
| `error` | One-line error summary (when `result_state == FAILED`) |
| `error_trace` | Full Python/JVM traceback — never truncate |

## Step 7: Clean Up

Always clean up, even on failure:

```bash
databricks workspace delete "${NOTEBOOK_PATH}" --profile <profile>
```

## Error Handling Reference

| Symptom | Likely cause | Action |
| ------- | ------------ | ------ |
| `ModuleNotFoundError` | whl not deployed or wrong path | Re-run `bundle deploy`, verify whl path |
| `INVALID_PARAMETER_VALUE` on submit | Bad `spark_version` or `node_type_id` | Check `bundle validate` output |
| Cluster launch error in `error_trace` | Node type unavailable in region | Check workspace cluster policies |
| `notebook_output.result` empty | No `dbutils.notebook.exit()` call | Add exit call to the file |
| Run not visible in Jobs UI | Expected — one-time submit runs are ephemeral | Use `jobs get-run` to check |

## Relationship to Other Skills

| Skill | Use for |
| ----- | ------- |
| `databricks-search` | Read-only SQL: list catalogs, describe tables, preview rows |
| `databricks-notebook` | Execute a local Python/PySpark file on a real cluster |
