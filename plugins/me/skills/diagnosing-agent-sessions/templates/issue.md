Title: <skill or symptom>: <one-line observable> (<harness>)

- [ ] I searched open and closed issues in `<owner/repo>` and this is not a duplicate (searched: <query terms>; closest: <issue and title, or "none">)

## Environment (required)

| Field | Value | Provenance / supporting evidence |
|-------|-------|---------------------------------|
| me version | <version> (<sha or "not a checkout">) | <evidence label>; <location> |
| Harness | <name> | <evidence label>; <location> |
| Harness version | <version> | <evidence label>; <location> |
| Model + version | <model ids seen> | <evidence label>; <location> |
| Other plugins | <list> | <evidence label>; <location> |
| OS + shell | <os version>, <shell> | <evidence label>; <location> |

## Involvement

The report found `me` involvement to be <possible | likely>, with evidence at
<transcript lines>. This does not establish cause.

## What happened?

<Problem statement and triage verdict, with `path:line` citations rewritten as `transcript line <n>`.>

## Steps to reproduce

1. <first human prompt, scrubbed>
2. <the turns leading to the problem, one line each>
3. <the observable>

## Expected behavior

<from the problem statement>

## Actual behavior

<from the triage verdict>

## Debug log or conversation transcript

Session id(s): <ids>. Local archive: <path, redaction level <level> | none built>.
Bundle attached by the human: <yes | no>.

---

Filed with the `diagnosing-agent-sessions` skill. Model, harness, harness
version, and installed plugins are listed above.
