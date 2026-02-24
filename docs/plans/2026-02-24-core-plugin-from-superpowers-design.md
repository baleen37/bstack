# Core Plugin Migration from Superpowers

**Date:** 2026-02-24
**Branch:** feat/good-bye-superpower
**Status:** Approved

## Goal

Migrate the `superpowers` marketplace plugin's skills and hooks into a self-owned `core` plugin within this repository. This removes the external dependency on `github.com/obra/superpowers` and gives full ownership of these foundational skills.

## What We're Migrating

Source: `/Users/jito.hello/.claude/plugins/cache/superpowers-marketplace/superpowers/4.3.1/`

- 14 skills (with subdirectories for some)
- `hooks/session-start` script
- `hooks/hooks.json`
- `hooks/run-hook.cmd`
- `lib/skills-core.js`

## Target Structure

```
plugins/core/
├── .claude-plugin/plugin.json
├── hooks/
│   ├── hooks.json
│   ├── run-hook.cmd
│   └── session-start
├── lib/
│   └── skills-core.js
└── skills/
    ├── brainstorming/SKILL.md
    ├── dispatching-parallel-agents/SKILL.md
    ├── executing-plans/SKILL.md
    ├── finishing-a-development-branch/SKILL.md
    ├── receiving-code-review/SKILL.md
    ├── requesting-code-review/
    │   ├── SKILL.md
    │   └── code-reviewer.md
    ├── subagent-driven-development/
    │   ├── SKILL.md
    │   ├── code-quality-reviewer-prompt.md
    │   ├── implementer-prompt.md
    │   └── spec-reviewer-prompt.md
    ├── systematic-debugging/
    │   ├── SKILL.md
    │   └── (supporting files)
    ├── test-driven-development/
    │   ├── SKILL.md
    │   └── testing-anti-patterns.md
    ├── using-core/SKILL.md          ← renamed from using-superpowers
    ├── using-git-worktrees/SKILL.md
    ├── verification-before-completion/SKILL.md
    ├── writing-plans/SKILL.md
    └── writing-skills/
        ├── SKILL.md
        └── (supporting files)
```

## Files Requiring Modification

### 1. `plugins/core/.claude-plugin/plugin.json`
- `name`: `"superpowers"` → `"core"`
- Remove external `author`, `homepage`, `repository` fields

### 2. `plugins/core/hooks/session-start`
- Reference to `skills/using-superpowers/SKILL.md` → `skills/using-core/SKILL.md`
- Output message: remove "superpowers" branding, update to "core"
- `<EXTREMELY_IMPORTANT>` block: update skill prefix references from `superpowers:` to `core:`

### 3. `plugins/core/skills/using-core/SKILL.md`
- All `superpowers:skill-name` references → `core:skill-name`
- Title/description updated to reflect `core` plugin

## marketplace.json Update

Add `core` plugin entry to `.claude-plugin/marketplace.json`:

```json
{
  "name": "core",
  "description": "Core development skills: TDD, debugging, brainstorming, collaboration patterns",
  "source": "./plugins/core",
  "category": "development",
  "tags": ["tdd", "debugging", "brainstorming", "workflow", "skills"],
  "version": "1.0.0"
}
```

## Post-Migration

Remove `superpowers` from `~/.claude/settings.json` plugins list (manual step after verifying `core` works).

## Out of Scope

- Modifying skill content beyond name/prefix changes
- Merging `using-git-worktrees` with the duplicate in `plugins/me/skills/` (separate task)
