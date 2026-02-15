---
name: eval
description: Eval-driven development - define, check, report, and list evals for AI agent tasks
argument-hint: [define|check|report|list|clean] <feature-name>
---

# Eval - Eval-Driven Development

Use and follow the eval-harness skill for principles and methodology.

## Subcommands

Parse `$ARGUMENTS` to determine the action. Default to `list` if no arguments provided.

### `/eval define <feature-name>`

Create a new eval definition:

1. Create `.claude/evals/` directory if it does not exist
2. Create `.claude/evals/<feature-name>.md` with this template:

```markdown
## EVAL: <feature-name>
Created: <current date>

### Capability Evals
- [ ] [Description of capability 1]
- [ ] [Description of capability 2]

### Regression Evals
- [ ] [Existing behavior 1 still works]
- [ ] [Existing behavior 2 still works]

### Success Criteria
- pass@3 > 90% for capability evals
- pass^3 = 100% for regression evals
```

3. Prompt to fill in specific criteria for the feature

### `/eval check <feature-name>`

Run evals for a feature:

1. Read eval definition from `.claude/evals/<feature-name>.md`
2. For each capability eval:
   - Attempt to verify the criterion
   - Record PASS/FAIL
   - Append result to `.claude/evals/<feature-name>.log`
3. For each regression eval:
   - Run relevant tests
   - Compare against baseline
   - Record PASS/FAIL
4. Report current status:

```
EVAL CHECK: <feature-name>
==========================
Capability: X/Y passing
Regression: X/Y passing
Status: IN PROGRESS / READY
```

### `/eval report <feature-name>`

Generate comprehensive eval report:

```
EVAL REPORT: <feature-name>
============================
Generated: <current date>

CAPABILITY EVALS
----------------
[eval-1]: PASS (pass@1)
[eval-2]: PASS (pass@2) - required retry
[eval-3]: FAIL - see notes

REGRESSION EVALS
----------------
[test-1]: PASS
[test-2]: PASS
[test-3]: PASS

METRICS
-------
Capability pass@1: X%
Capability pass@3: X%
Regression pass^3: X%

NOTES
-----
[Any issues, edge cases, or observations]

RECOMMENDATION
--------------
[SHIP / NEEDS WORK / BLOCKED]
```

### `/eval list`

Show all eval definitions found in `.claude/evals/`:

```
EVAL DEFINITIONS
================
feature-auth      [3/5 passing] IN PROGRESS
feature-search    [5/5 passing] READY
feature-export    [0/4 passing] NOT STARTED
```

If no evals exist, report that and suggest `/eval define <name>` to create one.

### `/eval clean`

Remove old eval logs, keeping the last 10 runs per feature. Report what was cleaned.
