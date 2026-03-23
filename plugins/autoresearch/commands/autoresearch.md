---
description: Start or resume autonomous experiment loop
argument-hint: [off | goal description]
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Skill
---

# Autoresearch Command

You are starting or resuming an autonomous experiment loop.

## Handle arguments

Arguments: $ARGUMENTS

### If arguments = "off"

Create a `.autoresearch-off` sentinel file in the current directory:
```bash
touch .autoresearch-off
```
Then tell the user autoresearch mode is paused. It can be resumed by running `/autoresearch` again (which will delete the sentinel).

### If `autoresearch.md` exists in the current directory (resume)

This is a resume. Do the following:

1. Delete `.autoresearch-off` if it exists
2. Read `autoresearch.md` to understand the objective, constraints, and what's been tried
3. Read `autoresearch.jsonl` to reconstruct state:
   - Count total runs, kept, discarded, crashed
   - Find baseline metric (first result in current segment)
   - Find best metric and which run achieved it
   - Identify which secondary metrics are being tracked
4. Read recent git log: `git log --oneline -20`
5. If `autoresearch.ideas.md` exists, read it for experiment inspiration
6. Continue the loop from where it left off — pick up the next experiment

### If `autoresearch.md` does NOT exist (fresh start)

1. Delete `.autoresearch-off` if it exists
2. Invoke the `autoresearch` skill to set up the experiment from scratch
3. If arguments were provided (other than "off"), use them as the goal description to skip/answer the setup questions
