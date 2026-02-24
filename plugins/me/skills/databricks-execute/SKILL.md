---
name: databricks-execute
description: Use when a user wants to run a Databricks job, trigger a specific task within a job, repair or re-run a failed task, or check job run status. Triggers on phrases like "run this job", "run only this task", "re-run the failed task", "trigger job", or "check job status".
---

# Databricks Execute

## Overview

Run Databricks jobs or specific tasks within a job via the Jobs API. Covers full job runs,
single-task runs, repair (re-run failed/specific tasks), and polling run status.

Use `databricks-notebook` when you need ad-hoc code execution on a fresh cluster.
Use this skill when working with **existing named jobs**.

## Prerequisites

- `databricks` CLI installed (`brew install databricks`)
- `~/.databrickscfg` configured with at least one profile
- Job must already exist (get `job_id` first — see Job Discovery below)

## Profile Selection

Default profile is `DEFAULT`. If user specifies one, pass `--profile <name>` to all commands.

```bash
grep '^\[' ~/.databrickscfg | tr -d '[]'   # list profiles
```

## Job Discovery

If the user gives a job name but not an ID, resolve it first:

```bash
databricks jobs list --profile <profile> --output json \
  | python3 -c "
import json, sys
jobs = json.load(sys.stdin).get('jobs', [])
for j in jobs:
    print(j['job_id'], j['settings']['name'])
"
```

---

## Use Case 1: Run a Full Job

```bash
databricks api post /api/2.2/jobs/run-now \
  --profile <profile> \
  --json '{"job_id": <job_id>}'
```

Capture `run_id` for polling (see Polling section).

With job parameters:

```json
{
  "job_id": 11223344,
  "job_parameters": {"env": "prod", "date": "2025-01-01"}
}
```

---

## Use Case 2: Run Only Specific Tasks

Use the `only` field (API 2.2) to run a subset of tasks by `task_key`:

```bash
databricks api post /api/2.2/jobs/run-now \
  --profile <profile> \
  --json '{
    "job_id": <job_id>,
    "only": ["task_key_1", "task_key_2"]
  }'
```

**Note:** `only` is an API 2.2 feature. If the workspace is on an older version, this field
will be silently ignored and all tasks will run. Verify behavior with the workspace admin.

To find task keys in an existing job:

```bash
databricks api get /api/2.1/jobs/get \
  --profile <profile> \
  --json '{"job_id": <job_id>}' \
  | python3 -c "
import json, sys
j = json.load(sys.stdin)
for t in j.get('settings', {}).get('tasks', []):
    deps = [d['task_key'] for d in t.get('depends_on', [])]
    print(t['task_key'], '  deps:', deps or '(none)')
"
```

---

## Use Case 3: Repair (Re-run Failed or Specific Tasks)

Use when a run already completed (TERMINATED) and you want to re-run specific tasks without
re-running the whole job:

```bash
databricks api post /api/2.2/jobs/runs/repair \
  --profile <profile> \
  --json '{
    "run_id": <run_id>,
    "rerun_tasks": ["task_key_1"]
  }'
```

Re-run all failed tasks automatically:

```json
{
  "run_id": <run_id>,
  "rerun_all_failed_tasks": true
}
```

Also re-run downstream dependents:

```json
{
  "run_id": <run_id>,
  "rerun_tasks": ["task_key_1"],
  "rerun_dependent_tasks": true
}
```

**Constraints:**

- `rerun_tasks` and `rerun_all_failed_tasks` are mutually exclusive
- Run must be TERMINATED (not in-progress) before repair
- Chaining repairs: pass `latest_repair_id` from previous repair response

---

## Polling Run Status

After any `run-now` or `repair`, poll until `life_cycle_state` is `TERMINATED` or `SKIPPED`:

```bash
RUN_ID=<run_id>
while true; do
  POLL=$(databricks jobs get-run "${RUN_ID}" --profile <profile> --output json \
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
  sleep 15
done
```

Result states: `SUCCESS`, `FAILED`, `TIMEDOUT`, `CANCELED`

Per-task status (for multi-task jobs):

```bash
databricks jobs get-run "${RUN_ID}" --profile <profile> --output json \
  | python3 -c "
import json, sys
r = json.load(sys.stdin)
for t in r.get('tasks', []):
    lc = t['state']['life_cycle_state']
    rs = t['state'].get('result_state', '')
    print(t['task_key'], lc, rs)
"
```

---

## Fetching Run Output

For notebook tasks:

```bash
databricks jobs get-run-output <run_id> --profile <profile> --output json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
rs = d.get('metadata', {}).get('state', {}).get('result_state', 'UNKNOWN')
nb = d.get('notebook_output', {}).get('result', '')
err = d.get('error', '')
tr = d.get('error_trace', '')
print('Result state:', rs)
if nb:  print('Exit value:', nb)
if err: print('Error:', err)
if tr:  print('--- Traceback ---'); print(tr)
"
```

`get-run-output` works on single-task runs. For multi-task jobs, call it with the
**task-level run ID** (`tasks[].run_id`), not the top-level run ID.

---

## Common Mistakes

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `only` field ignored, all tasks run | Workspace on API < 2.2 | Confirm API version with admin |
| Repair fails with "run still active" | Tried to repair in-progress run | Wait for TERMINATED state |
| `rerun_tasks` + `rerun_all_failed_tasks` both set | Mutually exclusive | Use one or the other |
| `get-run-output` returns empty | Called with top-level run_id on multi-task job | Use task-level `run_id` from `tasks[]` |
| Task keys not found | Typo or wrong job | List task keys with `jobs/get` first |

---

## Relationship to Other Skills

| Skill | Use for |
| ----- | ------- |
| `databricks-search` | Read-only SQL: list catalogs, describe tables, preview rows |
| `databricks-notebook` | Ad-hoc PySpark/Python code on a fresh cluster (no existing job) |
| `databricks-execute` | Trigger existing jobs; run/repair specific tasks by `task_key` |
