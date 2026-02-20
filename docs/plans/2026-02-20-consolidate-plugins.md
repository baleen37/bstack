# Plugin Consolidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge 12 separate plugins into a single monolithic plugin at the root level, removing `jira` and `databricks-devtools` entirely.

**Architecture:** All hook scripts, skills, and scripts move to root-level `hooks/`, `skills/`, and `scripts/` directories. A single `.claude-plugin/plugin.json` replaces all individual plugin JSONs. The `plugins/` directory is removed entirely.

**Tech Stack:** Bash shell scripts, JSON (plugin.json/hooks.json/marketplace.json), JavaScript (suggest-compacting dist files), semantic-release

---

## Before Starting

Verify clean git state:
```bash
git status
```
Expected: clean working tree. If not, commit or stash first.

---

### Task 1: Create new directory structure

**Files:**
- Create: `hooks/` (directory)
- Create: `scripts/` (directory)
- Create: `skills/` (directory)

**Step 1: Create directories**
```bash
mkdir -p hooks scripts skills
```

**Step 2: Verify**
```bash
ls -la | grep -E "^d.*(hooks|scripts|skills)"
```
Expected: 3 directories listed

**Step 3: Commit**
```bash
git add hooks scripts skills
git commit -m "chore: create root-level hook/script/skill directories for plugin consolidation"
```

---

### Task 2: Copy git-guard hook script

**Files:**
- Copy: `plugins/git-guard/hooks/commit-guard.sh` → `hooks/commit-guard.sh`

**Step 1: Copy file**
```bash
cp plugins/git-guard/hooks/commit-guard.sh hooks/commit-guard.sh
```

**Step 2: Verify content**
```bash
head -5 hooks/commit-guard.sh
```
Expected: `#!/usr/bin/env bash` header visible

**Step 3: Commit**
```bash
git add hooks/commit-guard.sh
git commit -m "chore: migrate git-guard commit-guard.sh to root hooks"
```

---

### Task 3: Copy handoff hook and scripts

**Files:**
- Copy: `plugins/handoff/hooks/session-start.sh` → `hooks/handoff-session-start.sh`
- Copy: `plugins/handoff/scripts/handoff.sh` → `scripts/handoff.sh`
- Copy: `plugins/handoff/scripts/pickup.sh` → `scripts/pickup.sh`
- Copy: `plugins/handoff/scripts/handoff-list.sh` → `scripts/handoff-list.sh`

**Step 1: Copy files**
```bash
cp plugins/handoff/hooks/session-start.sh hooks/handoff-session-start.sh
cp plugins/handoff/scripts/handoff.sh scripts/handoff.sh
cp plugins/handoff/scripts/pickup.sh scripts/pickup.sh
cp plugins/handoff/scripts/handoff-list.sh scripts/handoff-list.sh
```

**Step 2: Verify**
```bash
ls hooks/handoff-session-start.sh scripts/handoff.sh scripts/pickup.sh scripts/handoff-list.sh
```
Expected: all 4 files listed

**Step 3: Commit**
```bash
git add hooks/handoff-session-start.sh scripts/handoff.sh scripts/pickup.sh scripts/handoff-list.sh
git commit -m "chore: migrate handoff hooks and scripts to root level"
```

---

### Task 4: Copy suggest-compacting dist files

**Files:**
- Create: `dist/` (directory)
- Copy: `plugins/suggest-compacting/dist/auto-compact.js` → `dist/auto-compact.js`
- Copy: `plugins/suggest-compacting/dist/session-start.js` → `dist/session-start.js`

**Step 1: Create dist and copy**
```bash
mkdir -p dist
cp plugins/suggest-compacting/dist/auto-compact.js dist/auto-compact.js
cp plugins/suggest-compacting/dist/session-start.js dist/session-start.js
```

**Step 2: Verify**
```bash
ls dist/
```
Expected: `auto-compact.js  session-start.js`

**Step 3: Commit**
```bash
git add dist/
git commit -m "chore: migrate suggest-compacting dist files to root level"
```

---

### Task 5: Copy LSP check-install scripts

Each LSP plugin has an identical-pattern `check-install.sh`. They need to be renamed to avoid collision.

**Files:**
- Copy: `plugins/lsp-bash/hooks/check-install.sh` → `hooks/lsp-bash-check-install.sh`
- Copy: `plugins/lsp-typescript/hooks/check-install.sh` → `hooks/lsp-typescript-check-install.sh`
- Copy: `plugins/lsp-python/hooks/check-install.sh` → `hooks/lsp-python-check-install.sh`
- Copy: `plugins/lsp-go/hooks/check-install.sh` → `hooks/lsp-go-check-install.sh`
- Copy: `plugins/lsp-kotlin/hooks/check-install.sh` → `hooks/lsp-kotlin-check-install.sh`
- Copy: `plugins/lsp-lua/hooks/check-install.sh` → `hooks/lsp-lua-check-install.sh`
- Copy: `plugins/lsp-nix/hooks/check-install.sh` → `hooks/lsp-nix-check-install.sh`

**Step 1: Copy all LSP install scripts**
```bash
cp plugins/lsp-bash/hooks/check-install.sh hooks/lsp-bash-check-install.sh
cp plugins/lsp-typescript/hooks/check-install.sh hooks/lsp-typescript-check-install.sh
cp plugins/lsp-python/hooks/check-install.sh hooks/lsp-python-check-install.sh
cp plugins/lsp-go/hooks/check-install.sh hooks/lsp-go-check-install.sh
cp plugins/lsp-kotlin/hooks/check-install.sh hooks/lsp-kotlin-check-install.sh
cp plugins/lsp-lua/hooks/check-install.sh hooks/lsp-lua-check-install.sh
cp plugins/lsp-nix/hooks/check-install.sh hooks/lsp-nix-check-install.sh
```

**Step 2: Verify all 7 scripts are present**
```bash
ls hooks/lsp-*
```
Expected: 7 files listed

**Step 3: Commit**
```bash
git add hooks/lsp-*-check-install.sh
git commit -m "chore: migrate 7 LSP check-install scripts to root hooks"
```

---

### Task 6: Copy me plugin scripts and skills

**Files:**
- Copy: `plugins/me/scripts/check-conflicts.sh` → `scripts/check-conflicts.sh`
- Copy: `plugins/me/scripts/verify-pr-status.sh` → `scripts/verify-pr-status.sh`
- Copy: `plugins/me/skills/` → `skills/` (recursive)

**Step 1: Copy scripts**
```bash
cp plugins/me/scripts/check-conflicts.sh scripts/check-conflicts.sh
cp plugins/me/scripts/verify-pr-status.sh scripts/verify-pr-status.sh
```

**Step 2: Copy skills**
```bash
cp -r plugins/me/skills/gha skills/gha
cp -r plugins/me/skills/handoff skills/handoff
cp -r plugins/me/skills/reddit-fetch skills/reddit-fetch
cp -r plugins/me/skills/remembering-conversations skills/remembering-conversations
cp -r plugins/me/skills/review-claudemd skills/review-claudemd
```

**Step 3: Verify**
```bash
ls scripts/check-conflicts.sh scripts/verify-pr-status.sh
ls skills/
```
Expected: 2 scripts + 5 skill directories

**Step 4: Commit**
```bash
git add scripts/check-conflicts.sh scripts/verify-pr-status.sh skills/
git commit -m "chore: migrate me plugin scripts and skills to root level"
```

---

### Task 7: Write unified plugin.json

This replaces all 12 individual plugin.json files with a single root-level one.

**Files:**
- Modify: `.claude-plugin/plugin.json`

**Step 1: Read current root plugin.json**
```bash
cat .claude-plugin/plugin.json
```

**Step 2: Write unified plugin.json**

Write the following to `.claude-plugin/plugin.json`:

```json
{
  "name": "everything-agent",
  "version": "5.29.4",
  "description": "AI coding assistant toolkit - LSP servers, git workflow protection, session handoff, context management, and development automation",
  "author": {
    "name": "baleen37",
    "email": "git@baleen.me"
  },
  "license": "MIT",
  "keywords": [
    "lsp",
    "git",
    "workflow",
    "automation",
    "tdd",
    "debugging",
    "handoff",
    "memory",
    "context",
    "compacting",
    "bash",
    "typescript",
    "python",
    "go",
    "kotlin",
    "lua",
    "nix"
  ],
  "lspServers": {
    "bash": {
      "command": "bash-language-server",
      "args": ["start"],
      "extensionToLanguage": {
        ".sh": "bash",
        ".bash": "bash",
        ".zsh": "bash"
      }
    },
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".ts": "typescript",
        ".tsx": "typescript",
        ".js": "javascript",
        ".jsx": "javascript",
        ".mjs": "javascript",
        ".cjs": "javascript"
      }
    },
    "python": {
      "command": "pyright-langserver",
      "args": ["--stdio"],
      "extensionToLanguage": {
        ".py": "python",
        ".pyi": "python"
      }
    },
    "go": {
      "command": "gopls",
      "args": ["serve"],
      "extensionToLanguage": {
        ".go": "go"
      }
    },
    "kotlin": {
      "command": "kotlin-language-server",
      "extensionToLanguage": {
        ".kt": "kotlin",
        ".kts": "kotlin"
      }
    },
    "lua": {
      "command": "lua-language-server",
      "extensionToLanguage": {
        ".lua": "lua"
      }
    },
    "nix": {
      "command": "nil",
      "extensionToLanguage": {
        ".nix": "nix"
      }
    }
  }
}
```

**Step 3: Validate JSON**
```bash
jq . .claude-plugin/plugin.json > /dev/null && echo "Valid JSON"
```
Expected: `Valid JSON`

**Step 4: Commit**
```bash
git add .claude-plugin/plugin.json
git commit -m "feat: write unified plugin.json with all LSP servers consolidated"
```

---

### Task 8: Write unified hooks.json

This replaces all individual `hooks/hooks.json` files.

**Files:**
- Create: `hooks/hooks.json`

Note: `${CLAUDE_PLUGIN_ROOT}` is resolved at runtime to the plugin's root directory — which is now the repo root itself. All paths below use this variable.

**Step 1: Write hooks.json**

Write the following to `hooks/hooks.json`:

```json
{
  "description": "Everything Agent - unified hooks for all features",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/handoff-session-start.sh",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "bun ${CLAUDE_PLUGIN_ROOT}/dist/session-start.js"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/lsp-bash-check-install.sh &>/dev/null &"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/lsp-typescript-check-install.sh &>/dev/null &"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/lsp-python-check-install.sh &>/dev/null &"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/lsp-go-check-install.sh &>/dev/null &"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/lsp-kotlin-check-install.sh &>/dev/null &"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/lsp-lua-check-install.sh &>/dev/null &"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/lsp-nix-check-install.sh &>/dev/null &"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash:git",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/commit-guard.sh"
          }
        ]
      },
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bun ${CLAUDE_PLUGIN_ROOT}/dist/auto-compact.js"
          }
        ]
      }
    ]
  }
}
```

**Step 2: Validate JSON**
```bash
jq . hooks/hooks.json > /dev/null && echo "Valid JSON"
```
Expected: `Valid JSON`

**Step 3: Commit**
```bash
git add hooks/hooks.json
git commit -m "feat: write unified hooks.json combining all plugin hooks"
```

---

### Task 9: Update marketplace.json

Remove all individual plugins from the list. The root `everything-agent` entry stays but now points to `"./"`.

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Write simplified marketplace.json**

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "everything-agent",
  "description": "AI coding assistant toolkit - Claude Code, OpenCode, and more",
  "owner": {
    "name": "baleen",
    "email": "git@baleen.me"
  },
  "plugins": [
    {
      "name": "everything-agent",
      "description": "AI coding assistant toolkit - LSP servers, git workflow protection, session handoff, context management, and development automation",
      "source": "./",
      "category": "development",
      "tags": [
        "lsp",
        "git",
        "workflow",
        "automation",
        "tdd",
        "debugging",
        "handoff",
        "memory",
        "context"
      ],
      "version": "5.29.4"
    }
  ]
}
```

**Step 2: Validate JSON**
```bash
jq . .claude-plugin/marketplace.json > /dev/null && echo "Valid JSON"
```
Expected: `Valid JSON`

**Step 3: Commit**
```bash
git add .claude-plugin/marketplace.json
git commit -m "chore: simplify marketplace.json to single everything-agent plugin"
```

---

### Task 10: Update .releaserc.js

The `discoverPlugins()` function currently scans `plugins/*/`. After consolidation, there are no subdirectories — just the root `.claude-plugin/plugin.json`. The prepare step needs to update the root plugin.json directly.

**Files:**
- Modify: `.releaserc.js`

**Step 1: Read current file**
```bash
cat .releaserc.js
```

**Step 2: Replace the dynamic plugin discovery with direct root update**

Change the `updatePluginJsons` function. The new version:
- Skips `discoverPlugins()` entirely
- Updates `.claude-plugin/plugin.json` directly
- Updates `.claude-plugin/marketplace.json` as before

Replace the entire `updatePluginJsons` function and `discoverPlugins` function with:

```javascript
function updatePluginJsons() {
  return {
    async verifyConditions(_pluginContext, { lastRelease }) {
      if (!lastRelease || !lastRelease.version) {
        console.log('First release - skipping version verification');
        return;
      }

      const lastVersion = lastRelease.version;
      const pluginJsonPath = resolve(process.cwd(), '.claude-plugin/plugin.json');
      const pluginJson = JSON.parse(readFileSync(pluginJsonPath, 'utf8'));

      if (pluginJson.version !== lastVersion) {
        console.warn(`\n⚠️  plugin.json version mismatch: ${pluginJson.version} (expected ${lastVersion})`);
        console.warn('This will be synchronized to the next version.\n');
      }

      const marketplacePath = resolve(process.cwd(), '.claude-plugin/marketplace.json');
      const marketplace = JSON.parse(readFileSync(marketplacePath, 'utf8'));
      const marketplaceMismatches = marketplace.plugins.filter((p) => p.version !== lastVersion);

      if (marketplaceMismatches.length > 0) {
        console.warn('⚠️  Marketplace version mismatches:');
        marketplaceMismatches.forEach((p) => {
          console.warn(`  ${p.name}: ${p.version} (expected ${lastVersion})`);
        });
        console.warn('These will be synchronized to the next version.\n');
      }
    },

    async prepare(_pluginContext, { nextRelease: { version } }) {
      const pluginJsonPath = resolve(process.cwd(), '.claude-plugin/plugin.json');
      const pluginJson = JSON.parse(readFileSync(pluginJsonPath, 'utf8'));
      pluginJson.version = version;
      writeFileSync(pluginJsonPath, JSON.stringify(pluginJson, null, 2) + '\n');

      const marketplacePath = resolve(process.cwd(), '.claude-plugin/marketplace.json');
      const marketplace = JSON.parse(readFileSync(marketplacePath, 'utf8'));
      marketplace.plugins = marketplace.plugins.map((plugin) => ({ ...plugin, version }));
      writeFileSync(marketplacePath, JSON.stringify(marketplace, null, 2) + '\n');
    },
  };
}
```

Also update the `@semantic-release/git` assets array from:
```javascript
assets: [
  'plugins/*/.claude-plugin/plugin.json',
  '.claude-plugin/marketplace.json',
],
```
to:
```javascript
assets: [
  '.claude-plugin/plugin.json',
  '.claude-plugin/marketplace.json',
],
```

**Step 3: Verify JS syntax**
```bash
node --input-type=module < .releaserc.js && echo "Syntax OK"
```
Expected: `Syntax OK` (or no error output)

**Step 4: Commit**
```bash
git add .releaserc.js
git commit -m "refactor: simplify releaserc.js to manage single root plugin"
```

---

### Task 11: Remove plugins/ directory

This is the destructive step. Do it last, after all files are copied and verified.

**Step 1: Verify all source files exist at root level before deleting**
```bash
ls hooks/commit-guard.sh hooks/handoff-session-start.sh hooks/hooks.json
ls hooks/lsp-bash-check-install.sh hooks/lsp-typescript-check-install.sh
ls dist/auto-compact.js dist/session-start.js
ls scripts/handoff.sh scripts/pickup.sh scripts/handoff-list.sh
ls scripts/check-conflicts.sh scripts/verify-pr-status.sh
ls skills/gha/SKILL.md skills/handoff/SKILL.md skills/reddit-fetch/SKILL.md
```
Expected: all files present, no errors

**Step 2: Remove plugins directory**
```bash
git rm -r plugins/
```

**Step 3: Verify removal**
```bash
ls plugins/ 2>&1 || echo "plugins/ removed"
```
Expected: `plugins/ removed` or `No such file or directory`

**Step 4: Commit**
```bash
git commit -m "chore!: remove plugins/ directory - all plugins consolidated into root"
```

---

### Task 12: Run pre-commit hooks to verify everything passes

**Step 1: Run pre-commit on all files**
```bash
pre-commit run --all-files
```
Expected: all hooks pass. Fix any failures before continuing.

**Step 2: Run BATS tests (if applicable)**
```bash
bun run test:bats 2>/dev/null || echo "No BATS tests or skipped"
```

**Step 3: If pre-commit fails**

Common issues:
- JSON formatting: run `jq . file.json` and check output
- Shell script issues: run `shellcheck hooks/*.sh scripts/*.sh`
- Markdown issues: check any .md files you touched

Fix, stage, and commit any auto-fixes:
```bash
git add -p  # review changes carefully
git commit -m "fix: resolve pre-commit hook issues after consolidation"
```

---

### Task 13: Update CLAUDE.md and README.md references

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md` (if it references `plugins/` subdirectories)

**Step 1: Check for stale references to old plugin paths**
```bash
grep -r "plugins/" CLAUDE.md README.md 2>/dev/null || echo "No references found"
```

**Step 2: Check for references to removed plugins**
```bash
grep -rE "(jira|databricks)" CLAUDE.md README.md 2>/dev/null || echo "None found"
```

**Step 3: Update CLAUDE.md subdirectories table**

The `CLAUDE.md` has a table listing `plugins/` as a subdirectory. Update it to reflect new structure:
- Remove the `plugins/` row
- Add rows for `hooks/`, `scripts/`, `skills/`, `dist/` if useful

**Step 4: Commit any changes**
```bash
git add CLAUDE.md README.md
git commit -m "docs: update CLAUDE.md and README to reflect consolidated plugin structure"
```
If no changes needed, skip.

---

## Verification Checklist

After all tasks complete, verify:

```bash
# 1. Root structure is correct
ls -la | grep -E "^d" | grep -v "^\."

# 2. Plugin JSON is valid and has lspServers
jq '.lspServers | keys' .claude-plugin/plugin.json

# 3. Hooks JSON references correct paths
jq '.hooks' hooks/hooks.json

# 4. Marketplace has single entry
jq '.plugins | length' .claude-plugin/marketplace.json
# Expected: 1

# 5. No plugins/ directory
test ! -d plugins && echo "OK: plugins/ removed"

# 6. Git log shows clean history
git log --oneline -10
```

---

## Rollback

If anything goes wrong, the old structure is preserved in git history:

```bash
git log --oneline | grep "chore: create root-level"
# Find the commit before Task 1, then:
git revert HEAD~N  # or reset to that commit
```
