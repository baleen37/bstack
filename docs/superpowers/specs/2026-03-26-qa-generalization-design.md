# QA Skill Generalization Design

## Summary

Generalize the `/qa` skill from web-only to support any project type (web apps, CLI tools, API servers, libraries). Restructure the 11-phase web-specific workflow into a 5-phase universal flow. Project type is inferred naturally — no explicit detection logic needed.

## Problem

The current `/qa` skill is hardcoded for web application testing:
- All phases assume browser-based interaction (navigate, screenshot, click, extract)
- Health Score categories are web-specific (Console, Links, Visual, Accessibility)
- Issue taxonomy checklist is per-page browser exploration
- Report template has web-only fields (URL, Console Health, framework detection)

CLI tools, API servers, and libraries cannot be QA'd with this skill.

## Design

### Single SKILL.md with type-aware behavior

One skill file. The AI reads the project and knows what it is. No detection matrix or `--type` flags. The skill describes **what to do** at each phase, with type-specific guidance where strategies diverge.

### 5-Phase Universal Flow

Replaces the current 11-phase structure:

| Phase | Purpose | Replaces |
|-------|---------|----------|
| **1. Setup** | Parse params, clean tree check, test framework detect/bootstrap, create output dirs | Phase 1 (Initialize) |
| **2. Explore** | Systematically test the project using appropriate methods, document issues as found | Phases 2-6 (Auth, Orient, Explore, Document, Wrap Up) |
| **3. Fix Loop** | Triage by tier, then per-issue: locate → fix → commit → re-verify → regression test | Phases 7-8 (Triage, Fix Loop) |
| **4. Final QA** | Re-test all affected areas, compute before/after health score | Phase 9 (Final QA) |
| **5. Report** | Write report, save baseline, update TODOS.md | Phases 10-11 (Report, TODOS.md) |

### Phase 2 (Explore) — Type-Specific Strategies

The skill provides guidance for how to explore different project types, but trusts the AI to adapt:

**Web apps:** Browser-based. Navigate pages, click elements, fill forms, check console errors, test responsiveness. (Current behavior, largely preserved.)

**CLI tools:** Run the CLI with various inputs. Check help text, error messages, exit codes, edge cases. Also run existing test suite and cross-reference results.

**API servers:** Hit endpoints with real HTTP requests. Test auth flows, error responses, validation, edge cases. If an OpenAPI/Swagger spec exists, use it for coverage. Also run existing test suite.

**Libraries:** Run the test suite. Review public API surface for usability issues, missing edge case coverage, unclear error messages.

**Mixed projects** (e.g., API + web frontend): Test both aspects.

### Health Score

No fixed category set. The AI chooses categories appropriate to the project being tested. Web projects might use Console, Links, Visual, Functional, UX, Performance, Accessibility. A CLI might use Output Correctness, Error Handling, Edge Cases, Documentation, Performance. The scoring mechanic (start at 100, deduct per severity) stays the same.

### What Stays

- Three tiers: Quick / Standard / Exhaustive
- Diff-aware mode (automatic on feature branches)
- Regression mode (`--regression <baseline>`)
- Test Framework Bootstrap
- Fix Loop mechanics (8a–8f): locate → fix → commit → re-test → classify → regression test
- WTF-likelihood self-regulation + 50-fix hard cap
- One commit per fix
- Clean working tree requirement
- Issue severity levels (critical/high/medium/low)
- Report + baseline.json output

### What Changes

| Current | New |
|---------|-----|
| 11 phases | 5 phases |
| Browser Tool section at top | Browser guidance inside web-specific Explore notes |
| "web application" in description | Generic "project" language |
| Fixed Health Score categories (8 web-specific) | AI-chosen categories per project type |
| Per-Page Exploration Checklist | Type-aware exploration guidance |
| Console error collection snippets | Web-specific, moved into web Explore guidance |
| Framework detection (Next.js/Rails/WordPress/SPA) | Web-specific, kept as web Explore guidance |
| "Never refuse to use the browser" rule | Removed — browser used when project is web |
| Report template: URL required, Console Health section | All fields optional, template is generic |

### Files Changed

| File | Change |
|------|--------|
| `SKILL.md` | Rewrite: 5-phase universal flow, type-specific Explore guidance, generic rules |
| `references/issue-taxonomy.md` | Extend: add CLI/API/lib exploration checklists alongside existing web checklist |
| `templates/qa-report-template.md` | Generalize: make all fields optional, remove web-only assumptions |

## Out of Scope

- Separate skills per project type (`/qa-web`, `/qa-cli`, etc.)
- Separate reference documents per type
- Explicit type detection logic or `--type` parameter
- Mobile app testing (Appium etc.)
