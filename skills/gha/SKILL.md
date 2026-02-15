---
name: gha
description: This skill should be used when the user asks to "analyze GitHub Actions failure", "debug CI failure", "investigate workflow failure", "check why CI failed", "analyze this GitHub Actions run", or provides a GitHub Actions URL. Provides systematic investigation of GitHub Actions failures to identify root causes.
argument-hint: ---
Investigate this GitHub Actions URL: $ARGUMENTS
---

# GitHub Actions Failure Analysis

Systematically analyze GitHub Actions workflow failures to identify root causes using the `gh` CLI.

## Investigation Process

### Step 1: Get Basic Info & Identify Actual Failure

- What workflow/job failed, when, and on which commit?
- **CRITICAL**: Read the full logs carefully to find what **SPECIFICALLY** caused the exit code 1
- Distinguish between warnings/non-fatal errors vs actual failures
- Look for patterns like "failing:", "fatal:", or script logic that determines when to exit 1
- If both "non-fatal" and "fatal" errors appear, focus on what actually caused the failure

Use `gh run view <run-id> --log` to get full logs.

### Step 2: Check Flakiness

Check the past 10-20 runs of **THE EXACT SAME failing job**:

- **IMPORTANT**: If a workflow has multiple jobs, check history for the **SPECIFIC JOB** that failed, not just the workflow
- Use `gh run list --workflow=` to get run IDs, then `gh run view --json jobs` to check the specific job's status
- Is this a one-time failure or recurring pattern for THIS SPECIFIC JOB?
- What's the success rate for THIS JOB recently?
- When did THIS JOB last pass?

### Step 3: Identify Breaking Commit (if pattern exists)

If there's a pattern of failures for the specific job:

- Find the first run where **THIS SPECIFIC JOB** failed and the last run where it passed
- Identify the commit that introduced the failure
- Verify by checking: does THIS JOB fail in ALL runs after that commit? Does it pass in ALL runs before?
- If verified, report the breaking commit with high confidence

### Step 4: Root Cause Analysis

Based on logs, history, and any breaking commit:

- Focus on what **ACTUALLY** caused the failure (not just any errors seen)
- Verify the hypothesis against the logs and failure logic

### Step 5: Check for Existing Fix PRs

Search for open PRs that might already address this issue:

- Use `gh pr list --state open --search ""` with relevant error messages or file names
- Check if any open PR modifies the failing file/workflow
- If a fix PR exists, note it in the report and skip the recommendation section

## Final Report Format

Write a final report with:

- **Summary of failure**: What specifically triggered the exit code 1
- **Flakiness assessment**: One-time vs recurring, success rate
- **Breaking commit**: If identified and verified
- **Root cause analysis**: Based on the ACTUAL failure trigger
- **Existing fix PR**: If found - include PR number and link
- **Recommendation**: Skip if fix PR already exists

## Key Commands

```bash
# View workflow run details
gh run view <run-id>

# Get full logs
gh run view <run-id> --log

# List recent runs for a workflow
gh run list --workflow=<workflow-name> --limit 20

# Get job status as JSON
gh run view <run-id> --json jobs

# Search for open PRs
gh pr list --state open --search "<error-message-or-file-name>"
```
