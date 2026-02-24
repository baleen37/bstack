---
name: databricks-notebook
description: Use when a user wants to run, test, or debug a local Python/PySpark file on Databricks without waiting for a full job run. Requires a databricks.yml (DAB project). Triggered by phrases like "run this file on Databricks", "debug on cluster", "test this script", or "run as notebook".
---

# Databricks Notebook

## Overview

Run a local `.py` file on a Databricks all-purpose cluster by uploading it as a
temporary notebook and submitting a one-time run via `databricks jobs submit`.
Service code dependencies (`from search_data.xxx import ...`) are handled by
deploying the project whl via `bundle deploy` first.

**Requires a DAB project** (`databricks.yml` in the current directory).

**Do not use** `databricks-search` for this — that skill runs SQL via the Statements
API. This skill executes Python/PySpark code on a real cluster.

## Prerequisites

- `databricks` CLI installed (`brew install databricks`)
- `databricks.yml` present in the current directory (DAB project)
- `~/.databrickscfg` configured with the target profile
- An all-purpose cluster in RUNNING state (reused via `existing_cluster_id`)

## Workflow

```
1. RESOLVE  — get cluster ID and whl path from the bundle
2. DEPLOY   — bundle deploy to build and upload the whl
3. UPLOAD   — import local .py file to workspace as a notebook
4. SUBMIT   — one-time run via jobs submit
5. POLL     — wait for TERMINATED or SKIPPED state
6. OUTPUT   — fetch and display run output or error trace
7. CLEAN    — delete temporary notebook from workspace
```

## Step 1: Resolve Cluster ID and whl Path

Find the RUNNING all-purpose cluster:

```bash
CLUSTER_ID=$(databricks clusters list --profile <profile> --output json \
  | python3 -c "
import json, sys
clusters = json.load(sys.stdin)
for c in clusters:
    if c.get('cluster_source') == 'UI' and c.get('state') == 'RUNNING':
        print(c['cluster_id'])
        break
")
echo "CLUSTER_ID: ${CLUSTER_ID}"
```

If no RUNNING cluster is found, ask the user to start one from the Databricks UI.

Find the whl path from the bundle (after deploy, whl lands under `file_path/dist/`):

```bash
FILE_PATH=$(databricks bundle validate --target <target> --profile <profile> --output json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['workspace']['file_path'])")

WHL_PATH=$(databricks workspace list "${FILE_PATH}/dist" --profile <profile> --output json \
  | python3 -c "
import json, sys
files = json.load(sys.stdin)
for f in files:
    if f['path'].endswith('.whl'):
        print(f['path'])
        break
")
echo "WHL_PATH: ${WHL_PATH}"
```

`WHL_PATH` will be empty before the first `bundle deploy` — that's expected. Proceed to Step 2.

## Step 2: Deploy Bundle

Build the whl and upload it to the workspace:

```bash
databricks bundle deploy --target <target> --profile <profile>
```

If the deploy fails due to a git branch mismatch, add `--force`:

```bash
databricks bundle deploy --target <target> --profile <profile> --force
```

After deploy, re-run the `WHL_PATH` command from Step 1 to capture the path.

## Step 3: Upload Local File as Notebook

Upload the local `.py` file to a timestamped path in the workspace:

```bash
TIMESTAMP=$(date +%s)
ROOT_PATH=$(databricks bundle validate --target <target> --profile <profile> --output json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['workspace']['root_path'])")
NOTEBOOK_PATH="${ROOT_PATH}/tmp/claude-nb-${TIMESTAMP}"

databricks workspace import "${NOTEBOOK_PATH}" \
  --profile <profile> \
  --file <local-file.py> \
  --format SOURCE \
  --language PYTHON \
  --overwrite
```

**Rules:**
- `spark` is already available in notebook context — do not add `SparkSession.builder`.
- `notebook_output.result` only captures `dbutils.notebook.exit()` — `print()` is not captured on success.
- If the file has no `dbutils.notebook.exit()` call, append a cell at the end:

```python
# COMMAND ----------
dbutils.notebook.exit("done")
```

## Step 4: Submit One-Time Run

Pass variables via environment to avoid shell quoting issues:

```bash
PAYLOAD=$(CLUSTER_ID="${CLUSTER_ID}" NOTEBOOK_PATH="${NOTEBOOK_PATH}" WHL_PATH="${WHL_PATH}" \
  python3 - <<'EOF'
import json, os

task = {
    "task_key": "main",
    "notebook_task": {
        "notebook_path": os.environ["NOTEBOOK_PATH"],
        "source": "WORKSPACE",
    },
    "existing_cluster_id": os.environ["CLUSTER_ID"],
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
- `existing_cluster_id` reuses the running cluster — no cluster startup wait.

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
  if [ "$LC" = "TERMINATED" ] || [ "$LC" = "SKIPPED" ] || [ "$LC" = "INTERNAL_ERROR" ]; then break; fi
  sleep 10
done
```

After the loop, check `RS`:
- `SUCCESS` → proceed to Step 6
- `FAILED` → proceed to Step 6 (error details in output)
- `TIMEDOUT` → cancel with `databricks jobs cancel-run "${RUN_ID}" --profile <profile>`
- `CANCELED` / `INTERNAL_ERROR` → inform user

## Step 6: Fetch and Display Output

For multi-task runs, fetch output via the task's run_id (not the parent run_id):

```bash
TASK_RUN_ID=$(databricks jobs get-run "${RUN_ID}" --profile <profile> --output json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['tasks'][0]['run_id'])")

databricks jobs get-run-output "${TASK_RUN_ID}" --profile <profile> --output json \
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
| `ModuleNotFoundError` | whl not deployed or wrong path | Re-run `bundle deploy`, re-capture `WHL_PATH` |
| No RUNNING cluster found | Cluster stopped | Start cluster from Databricks UI |
| `bundle deploy` git branch error | Local branch ≠ bundle target branch | Add `--force` flag |
| `notebook_output.result` empty | No `dbutils.notebook.exit()` call | Add exit call to the file |
| Run not visible in Jobs UI | Expected — one-time submit runs are ephemeral | Use `jobs get-run` to check |

## Relationship to Other Skills

| Skill | Use for |
| ----- | ------- |
| `databricks-search` | Read-only SQL: list catalogs, describe tables, preview rows |
| `databricks-notebook` | Execute a local Python/PySpark file on a real cluster |
