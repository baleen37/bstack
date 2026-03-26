# me/qa Skill Design

## Summary

Port gstack's `/qa` skill into the `me` plugin as an independent skill, replacing gstack-specific binaries and telemetry with `superpowers-chrome` browser control.

## Problem

gstack's `/qa` is a comprehensive QA skill (test → fix → verify loop) but requires the full gstack toolchain:
- `~/.claude/skills/gstack/bin/` binaries (gstack-config, gstack-update-check, gstack-repo-mode, gstack-telemetry-log, gstack-slug)
- `~/.claude/skills/gstack/browse/dist/browse` headless browser binary
- `~/.gstack/` directory structure for sessions, analytics, and project context

The `me` plugin should provide this capability without gstack dependency.

## Decision: Independent version using superpowers-chrome

Remove all gstack-specific infrastructure. Replace the `$B` browse binary with `mcp__plugin_superpowers-chrome_chrome__use_browser` tool calls.

## What's Removed

| Removed | Reason |
|---------|--------|
| Preamble (update check, sessions, telemetry) | gstack infrastructure not applicable |
| Contributor Mode | gstack-specific feedback loop |
| "Boil the Lake" / Completeness Principle | gstack philosophy, not needed in me |
| "Search Before Building" section | gstack-specific philosophy |
| AskUserQuestion Format section | gstack-specific formatting rules |
| `~/.gstack/` directory references | gstack infrastructure |
| Project-scoped test plan storage (`~/.gstack/projects/`) | gstack infrastructure |
| `gstack-slug` binary usage | Replaced with inline git commands |
| Plan Status Footer | gstack plan review integration |
| Step 0: Detect base branch | gstack preamble artifact |

## What's Kept (core workflow intact)

- All 11 phases: Init → Auth → Orient → Explore → Document → Wrap Up → Triage → Fix Loop → Final QA → Report → TODOS
- Health Score Rubric (Console/Links/Visual/Functional/UX/Performance/Content/Accessibility)
- Fix Loop (8a–8f): locate → fix → commit → re-test → classify → regression test
- WTF-likelihood self-regulation heuristic
- Hard cap of 50 fixes
- Three tiers: Quick / Standard / Exhaustive
- Diff-aware mode (automatic when on a feature branch)
- Regression mode (`--regression <baseline>`)
- Test Framework Bootstrap
- Report template and issue taxonomy

## Browser Command Mapping

| gstack `$B` | use_browser action |
|---|---|
| `$B goto <url>` | `{action: "navigate", payload: url}` |
| `$B snapshot -i -a -o file.png` | `{action: "screenshot", payload: "file.png"}` then Read |
| `$B console --errors` | `{action: "eval", payload: "JSON.stringify(window.__qaErrors)"}` |
| `$B click @e5` | `{action: "click", selector: "..."}` |
| `$B fill @e3 "text"` | `{action: "type", selector: "...", payload: "text"}` |
| `$B links` | `{action: "eval", payload: "Array.from(document.querySelectorAll('a')).map(a=>a.href)"}` |
| `$B snapshot -D` | `{action: "extract", payload: "markdown"}` (compare two) |
| `$B viewport 375x812` | `{action: "eval", payload: "window.resizeTo(375, 812)"}` |

## Output Path Change

- gstack: `.gstack/qa-reports/`
- me: `.qa/reports/`

## File Structure

```
plugins/me/skills/qa/
├── SKILL.md
├── references/
│   └── issue-taxonomy.md
└── templates/
    └── qa-report-template.md
```
