# Autoresearch `.autoresearch/` Consolidation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all autoresearch output files from project root into `.autoresearch/` directory.

**Architecture:** Pure path renaming across 3 plugin files. No logic changes. Hook checks `.autoresearch/autoresearch.md` instead of `autoresearch.md`.

**Tech Stack:** Bash (hook), Markdown (command + skill)

---

### Task 1: Update hook script

**Files:**
- Modify: `plugins/autoresearch/hooks/autoresearch-context.sh`

- [ ] **Step 1: Update path checks and file references**

Replace the entire file content with:

```bash
#!/bin/bash
# Autoresearch Context Injection Hook (UserPromptSubmit)
#
# When autoresearch mode is active (.autoresearch/autoresearch.md exists
# and no .autoresearch/off sentinel), injects a reminder into every user
# message so the agent stays in the loop.

if [ -f ".autoresearch/autoresearch.md" ] && [ ! -f ".autoresearch/off" ]; then
  cat << 'EOF'
## Autoresearch Mode (ACTIVE)
You are in autoresearch mode. Read .autoresearch/autoresearch.md for your objective and rules.
Use .autoresearch/autoresearch.jsonl for state. NEVER STOP until interrupted.
Run experiments, log results, keep winners, discard losers. Loop forever.
If .autoresearch/ideas.md exists, use it for experiment inspiration.
User messages during experiments are steers — finish your current experiment, log it, then incorporate the user's idea in the next experiment.
EOF
fi
```

- [ ] **Step 2: Verify the script is valid bash**

Run: `bash -n plugins/autoresearch/hooks/autoresearch-context.sh`
Expected: no output (valid syntax)

- [ ] **Step 3: Commit**

```bash
git add plugins/autoresearch/hooks/autoresearch-context.sh
git commit -m "refactor(autoresearch): update hook to use .autoresearch/ paths"
```

---

### Task 2: Update command file

**Files:**
- Modify: `plugins/autoresearch/commands/autoresearch.md`

- [ ] **Step 1: Update all path references**

Apply these changes to `plugins/autoresearch/commands/autoresearch.md`:

1. "off" handler: `touch .autoresearch-off` → `mkdir -p .autoresearch && touch .autoresearch/off`
2. Resume condition: `` If `autoresearch.md` exists `` → `` If `.autoresearch/autoresearch.md` exists ``
3. Resume step 1: `Delete `.autoresearch-off` if it exists` → `Delete `.autoresearch/off` if it exists`
4. Resume step 2: `Read `autoresearch.md`` → `Read `.autoresearch/autoresearch.md``
5. Resume step 3: `Read `autoresearch.jsonl`` → `Read `.autoresearch/autoresearch.jsonl``
6. Resume step 5: `If `autoresearch.ideas.md` exists` → `If `.autoresearch/ideas.md` exists`
7. Fresh start condition: `` If `autoresearch.md` does NOT exist `` → `` If `.autoresearch/autoresearch.md` does NOT exist ``
8. Fresh start step 1: `Delete `.autoresearch-off` if it exists` → `Delete `.autoresearch/off` if it exists`

Full resulting file:

```markdown
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

Create a `.autoresearch/off` sentinel file in the current directory:
` ``bash
mkdir -p .autoresearch && touch .autoresearch/off
` ``
Then tell the user autoresearch mode is paused. It can be resumed by running `/autoresearch` again (which will delete the sentinel).

### If `.autoresearch/autoresearch.md` exists in the current directory (resume)

This is a resume. Do the following:

1. Delete `.autoresearch/off` if it exists
2. Read `.autoresearch/autoresearch.md` to understand the objective, constraints, and what's been tried
3. Read `.autoresearch/autoresearch.jsonl` to reconstruct state:
   - Count total runs, kept, discarded, crashed
   - Find baseline metric (first result in current segment)
   - Find best metric and which run achieved it
   - Identify which secondary metrics are being tracked
4. Read recent git log: `git log --oneline -20`
5. If `.autoresearch/ideas.md` exists, read it for experiment inspiration
6. Continue the loop from where it left off — pick up the next experiment

### If `.autoresearch/autoresearch.md` does NOT exist (fresh start)

1. Delete `.autoresearch/off` if it exists
2. Invoke the `autoresearch` skill to set up the experiment from scratch
3. If arguments were provided (other than "off"), use them as the goal description to skip/answer the setup questions
```

- [ ] **Step 2: Commit**

```bash
git add plugins/autoresearch/commands/autoresearch.md
git commit -m "refactor(autoresearch): update command to use .autoresearch/ paths"
```

---

### Task 3: Update skill file

**Files:**
- Modify: `plugins/autoresearch/skills/autoresearch/SKILL.md`

This is the largest file. All path references need updating:

- [ ] **Step 1: Update Setup section**

In the Setup section (line 15):
- `mkdir -p experiments` → `mkdir -p .autoresearch`
- `autoresearch.md`, `autoresearch.sh`, and `experiments/worklog.md` → `.autoresearch/autoresearch.md`, `.autoresearch/run.sh`, and `.autoresearch/worklog.md`

- [ ] **Step 2: Update `autoresearch.md` subsection**

In the "How to Run" template (line 33):
- `` `./autoresearch.sh` `` → `` `./.autoresearch/run.sh` ``

- [ ] **Step 3: Update `autoresearch.sh` subsection**

Rename section header from `### \`autoresearch.sh\`` to `### \`.autoresearch/run.sh\``

- [ ] **Step 4: Update JSONL State Protocol section**

All `autoresearch.jsonl` references → `.autoresearch/autoresearch.jsonl`

In initialization bash blocks:
- `> autoresearch.jsonl` → `> .autoresearch/autoresearch.jsonl`
- `>> autoresearch.jsonl` → `>> .autoresearch/autoresearch.jsonl`

- [ ] **Step 5: Update Running Experiments section**

- `./autoresearch.sh` → `./.autoresearch/run.sh`

- [ ] **Step 6: Update Logging Results section**

In "Append result to JSONL":
- `>> autoresearch.jsonl` → `>> .autoresearch/autoresearch.jsonl`

In "Update dashboard":
- `autoresearch-dashboard.md` → `.autoresearch/dashboard.md`

In "Append to worklog":
- `experiments/worklog.md` → `.autoresearch/worklog.md`

In "On setup/On resume" paragraph:
- `experiments/worklog.md` → `.autoresearch/worklog.md`

- [ ] **Step 7: Update Dashboard section**

- `autoresearch-dashboard.md` → `.autoresearch/dashboard.md`

- [ ] **Step 8: Update Loop Rules section**

In "Resuming" bullet:
- `autoresearch.md` → `.autoresearch/autoresearch.md`
- `autoresearch.jsonl` → `.autoresearch/autoresearch.jsonl`
- `experiments/worklog.md` → `.autoresearch/worklog.md`

- [ ] **Step 9: Update Ideas Backlog section**

- `autoresearch.ideas.md` → `.autoresearch/ideas.md` (all occurrences)

- [ ] **Step 10: Update "Updating autoresearch.md" section**

- `autoresearch.md` → `.autoresearch/autoresearch.md`

- [ ] **Step 11: Verify no old paths remain**

Run: `grep -n 'autoresearch\.md\|autoresearch\.jsonl\|autoresearch\.sh\|autoresearch-dashboard\|autoresearch\.ideas\|autoresearch-off\|experiments/worklog' plugins/autoresearch/skills/autoresearch/SKILL.md`

Every match should be prefixed with `.autoresearch/`. No bare `autoresearch.md` at root level should remain (except inside the template content of `autoresearch.md` itself where it refers to its own "What's Been Tried" section header).

- [ ] **Step 12: Commit**

```bash
git add plugins/autoresearch/skills/autoresearch/SKILL.md
git commit -m "refactor(autoresearch): update skill to use .autoresearch/ paths"
```

---

### Task 4: Final verification

- [ ] **Step 1: Grep all plugin files for stale paths**

Run: `grep -rn 'autoresearch-off\|autoresearch-dashboard\|experiments/worklog' plugins/autoresearch/`

Expected: no matches

- [ ] **Step 2: Grep for bare root-level paths**

Run: `grep -rn '"autoresearch\.\|`autoresearch\.' plugins/autoresearch/ | grep -v '\.autoresearch/'`

Expected: no matches (all references should use `.autoresearch/` prefix)

- [ ] **Step 3: Verify hook syntax**

Run: `bash -n plugins/autoresearch/hooks/autoresearch-context.sh`
Expected: no output
