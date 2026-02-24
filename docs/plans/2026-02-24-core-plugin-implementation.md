# Core Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use core:executing-plans to implement this plan task-by-task.

**Goal:** Create `plugins/core` by copying superpowers 4.3.1 skills/hooks into this repo and renaming all `superpowers` references to `core` (including `using-superpowers` → `using-core`).

**Architecture:** Copy files verbatim from the cached superpowers plugin, then apply targeted string replacements for naming. No new logic is introduced — this is purely a structural migration.

**Tech Stack:** bash, jq, existing BATS test infrastructure

---

### Task 1: Create directory structure

**Files:**
- Create: `plugins/core/.claude-plugin/` (directory)
- Create: `plugins/core/hooks/` (directory)
- Create: `plugins/core/lib/` (directory)
- Create: `plugins/core/skills/` (directory)

**Step 1: Create the directories**

```bash
mkdir -p plugins/core/.claude-plugin
mkdir -p plugins/core/hooks
mkdir -p plugins/core/lib
mkdir -p plugins/core/skills
```

**Step 2: Verify**

```bash
ls plugins/core/
```
Expected: `.claude-plugin  hooks  lib  skills`

**Step 3: Commit**

```bash
git add plugins/core/
git commit -m "chore(core): scaffold core plugin directory structure"
```

---

### Task 2: Copy skills from superpowers

Source: `/Users/jito.hello/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1/skills/`

**Files to copy** (14 skills, some with subdirectories):
- `brainstorming/SKILL.md`
- `dispatching-parallel-agents/SKILL.md`
- `executing-plans/SKILL.md`
- `finishing-a-development-branch/SKILL.md`
- `receiving-code-review/SKILL.md`
- `requesting-code-review/SKILL.md` + `requesting-code-review/code-reviewer.md`
- `subagent-driven-development/SKILL.md` + 3 prompt files
- `systematic-debugging/SKILL.md` + supporting files (CREATION-LOG.md, condition-based-waiting-example.ts, condition-based-waiting.md, defense-in-depth.md, find-polluter.sh, root-cause-tracing.md, test-academic.md, test-pressure-1.md, test-pressure-2.md, test-pressure-3.md)
- `test-driven-development/SKILL.md` + `testing-anti-patterns.md`
- `using-git-worktrees/SKILL.md`
- `using-superpowers/SKILL.md` ← will be renamed to `using-core/` in Task 4
- `verification-before-completion/SKILL.md`
- `writing-plans/SKILL.md`
- `writing-skills/SKILL.md` + supporting files (anthropic-best-practices.md, graphviz-conventions.dot, persuasion-principles.md, render-graphs.js, testing-skills-with-subagents.md, examples/CLAUDE_MD_TESTING.md)

**Step 1: Copy all skills**

```bash
SUPERPOWERS=/Users/jito.hello/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1/skills
cp -r "$SUPERPOWERS/." plugins/core/skills/
```

**Step 2: Verify skill count**

```bash
ls plugins/core/skills/ | wc -l
```
Expected: `14`

**Step 3: Verify a specific skill**

```bash
head -3 plugins/core/skills/brainstorming/SKILL.md
```
Expected: frontmatter with `name: brainstorming`

**Step 4: Commit**

```bash
git add plugins/core/skills/
git commit -m "chore(core): copy superpowers skills verbatim"
```

---

### Task 3: Copy hooks and lib

**Step 1: Copy hooks**

```bash
SUPERPOWERS=/Users/jito.hello/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1
cp "$SUPERPOWERS/hooks/hooks.json" plugins/core/hooks/
cp "$SUPERPOWERS/hooks/run-hook.cmd" plugins/core/hooks/
cp "$SUPERPOWERS/hooks/session-start" plugins/core/hooks/
cp "$SUPERPOWERS/lib/skills-core.js" plugins/core/lib/
```

**Step 2: Make session-start executable**

```bash
chmod +x plugins/core/hooks/session-start
```

**Step 3: Verify**

```bash
ls plugins/core/hooks/
ls plugins/core/lib/
```
Expected hooks: `hooks.json  run-hook.cmd  session-start`
Expected lib: `skills-core.js`

**Step 4: Commit**

```bash
git add plugins/core/hooks/ plugins/core/lib/
git commit -m "chore(core): copy superpowers hooks and lib verbatim"
```

---

### Task 4: Rename using-superpowers → using-core

**Files:**
- Rename: `plugins/core/skills/using-superpowers/` → `plugins/core/skills/using-core/`

**Step 1: Rename the directory**

```bash
mv plugins/core/skills/using-superpowers plugins/core/skills/using-core
```

**Step 2: Verify**

```bash
ls plugins/core/skills/using-core/
```
Expected: `SKILL.md`

**Step 3: Commit**

```bash
git add plugins/core/skills/
git commit -m "chore(core): rename using-superpowers to using-core"
```

---

### Task 5: Update using-core/SKILL.md content

Replace all `superpowers:` skill prefix references with `core:` and update the skill name/description in the frontmatter.

**Files:**
- Modify: `plugins/core/skills/using-core/SKILL.md`

**Step 1: Read the current file**

```bash
cat plugins/core/skills/using-core/SKILL.md
```

**Step 2: Replace frontmatter name and description**

Edit the frontmatter:
```yaml
---
name: using-core
description: Use when starting any conversation - establishes how to find and use skills, requiring Skill tool invocation before ANY response including clarifying questions
---
```

**Step 3: Replace all `superpowers:` prefixes in the body**

Use sed to replace every occurrence of `superpowers:` with `core:`:

```bash
sed -i '' 's/superpowers:/core:/g' plugins/core/skills/using-core/SKILL.md
```

**Step 4: Verify no `superpowers:` references remain**

```bash
grep "superpowers:" plugins/core/skills/using-core/SKILL.md
```
Expected: no output

**Step 5: Verify `core:` references are present**

```bash
grep "core:" plugins/core/skills/using-core/SKILL.md | head -5
```
Expected: lines like `core:brainstorming`, `core:systematic-debugging`, etc.

**Step 6: Commit**

```bash
git add plugins/core/skills/using-core/SKILL.md
git commit -m "feat(core): update using-core skill with core: prefix"
```

---

### Task 6: Update session-start hook

The hook reads `skills/using-superpowers/SKILL.md` and injects it as context. Update it to:
1. Read `skills/using-core/SKILL.md` instead
2. Remove "You have superpowers." branding → "You have core skills."
3. Update the `<EXTREMELY_IMPORTANT>` label to reference `core:using-core`

**Files:**
- Modify: `plugins/core/hooks/session-start`

**Step 1: Read current file**

```bash
cat plugins/core/hooks/session-start
```

**Step 2: Apply replacements**

```bash
sed -i '' \
  's|skills/using-superpowers/SKILL.md|skills/using-core/SKILL.md|g' \
  plugins/core/hooks/session-start

sed -i '' \
  "s|'superpowers:using-superpowers' skill|'core:using-core' skill|g" \
  plugins/core/hooks/session-start

sed -i '' \
  's|You have superpowers\.|You have core skills.|g' \
  plugins/core/hooks/session-start
```

**Step 3: Verify no `superpowers` references remain**

```bash
grep -i "superpowers" plugins/core/hooks/session-start
```
Expected: no output

**Step 4: Run the hook manually to verify output is valid JSON**

```bash
CLAUDE_PLUGIN_ROOT="$(pwd)/plugins/core" bash plugins/core/hooks/session-start | python3 -m json.tool > /dev/null && echo "Valid JSON"
```
Expected: `Valid JSON`

**Step 5: Commit**

```bash
git add plugins/core/hooks/session-start
git commit -m "feat(core): update session-start hook for core plugin"
```

---

### Task 7: Create plugin.json

**Files:**
- Create: `plugins/core/.claude-plugin/plugin.json`

**Step 1: Write plugin.json**

```json
{
  "name": "core",
  "description": "Core development skills: TDD, debugging, brainstorming, collaboration patterns, and proven techniques",
  "version": "1.0.0",
  "keywords": ["skills", "tdd", "debugging", "brainstorming", "collaboration", "best-practices", "workflows"]
}
```

**Step 2: Verify valid JSON**

```bash
python3 -m json.tool plugins/core/.claude-plugin/plugin.json > /dev/null && echo "Valid JSON"
```
Expected: `Valid JSON`

**Step 3: Commit**

```bash
git add plugins/core/.claude-plugin/plugin.json
git commit -m "feat(core): add plugin.json for core plugin"
```

---

### Task 8: Register core in marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Read current marketplace.json**

```bash
cat .claude-plugin/marketplace.json
```

**Step 2: Add core plugin entry**

Add after the `"me"` plugin entry (first item in `"plugins"` array):

```json
{
  "name": "core",
  "description": "Core development skills: TDD, debugging, brainstorming, collaboration patterns",
  "source": "./plugins/core",
  "category": "development",
  "tags": [
    "tdd",
    "debugging",
    "brainstorming",
    "workflow",
    "skills"
  ],
  "version": "1.0.0"
}
```

**Step 3: Verify valid JSON**

```bash
python3 -m json.tool .claude-plugin/marketplace.json > /dev/null && echo "Valid JSON"
```
Expected: `Valid JSON`

**Step 4: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(core): register core plugin in marketplace.json"
```

---

### Task 9: Verify no remaining superpowers references in plugins/core

**Step 1: Search for any remaining superpowers references**

```bash
grep -r "superpowers" plugins/core/ --include="*.md" --include="*.json" --include="*.sh" --include="*.js" -l
```
Expected: no output (or only acceptable references in skill body text about the history/migration)

**Step 2: If any files found, inspect and fix**

For each file returned, check if the reference is:
- A functional reference (path, skill name, brand) → fix it
- Historical/explanatory text → acceptable, leave it

**Step 3: Run BATS tests**

```bash
bats tests/
```
Expected: all tests pass

**Step 4: Final commit if any fixes were needed**

```bash
git add -p
git commit -m "fix(core): remove remaining superpowers references"
```

---

### Task 10: Smoke test the session-start hook

**Step 1: Run session-start and inspect output**

```bash
CLAUDE_PLUGIN_ROOT="$(pwd)/plugins/core" bash plugins/core/hooks/session-start
```

Expected: JSON output containing:
- `"additional_context"` key
- Text referencing `core:using-core`
- Text saying "You have core skills."
- The full content of `plugins/core/skills/using-core/SKILL.md` embedded in the JSON

**Step 2: Confirm the using-core skill content is correct inside the JSON**

```bash
CLAUDE_PLUGIN_ROOT="$(pwd)/plugins/core" bash plugins/core/hooks/session-start | python3 -c "
import json, sys
data = json.load(sys.stdin)
ctx = data['hookSpecificOutput']['additionalContext']
assert 'core:using-core' in ctx, 'Missing core:using-core reference'
assert 'superpowers' not in ctx, 'Found superpowers reference in output'
print('All assertions passed')
"
```
Expected: `All assertions passed`

**Step 3: Commit if no issues, otherwise fix and re-run**

---

### Task 11: Update writing-plans SKILL.md header template

The `writing-plans` skill contains a plan header template that references `superpowers:executing-plans`. Update it to reference `core:executing-plans`.

**Files:**
- Modify: `plugins/core/skills/writing-plans/SKILL.md`

**Step 1: Check current content**

```bash
grep "superpowers:" plugins/core/skills/writing-plans/SKILL.md
```

**Step 2: Replace**

```bash
sed -i '' 's/superpowers:/core:/g' plugins/core/skills/writing-plans/SKILL.md
```

**Step 3: Verify**

```bash
grep "superpowers:" plugins/core/skills/writing-plans/SKILL.md
```
Expected: no output

**Step 4: Commit**

```bash
git add plugins/core/skills/writing-plans/SKILL.md
git commit -m "fix(core): update writing-plans skill to use core: prefix"
```

---

### Task 12: Check all other skills for superpowers: references

Some skills (brainstorming, subagent-driven-development, etc.) may reference other `superpowers:` skills internally.

**Step 1: Find all occurrences**

```bash
grep -r "superpowers:" plugins/core/skills/ --include="*.md" -n
```

**Step 2: For each occurrence, replace `superpowers:` with `core:`**

```bash
find plugins/core/skills/ -name "*.md" -exec sed -i '' 's/superpowers:/core:/g' {} +
```

**Step 3: Verify clean**

```bash
grep -r "superpowers:" plugins/core/skills/ --include="*.md"
```
Expected: no output

**Step 4: Run BATS tests again**

```bash
bats tests/
```
Expected: all tests pass

**Step 5: Commit**

```bash
git add plugins/core/skills/
git commit -m "fix(core): replace all superpowers: skill references with core:"
```
