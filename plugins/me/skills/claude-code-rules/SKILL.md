---
name: claude-code-rules
description: Use when creating, organizing, or improving Claude Code rules files in .claude/rules/ — modular project or user-level instructions that Claude automatically loads
---

# Claude Code Rules

Rules are markdown files Claude Code automatically loads as memory. Use them to encode persistent standards without bloating CLAUDE.md.

## Where Rules Live

| Scope | Path | Priority |
|-------|------|----------|
| User (global) | `~/.claude/rules/*.md` | Lower (loaded first) |
| Project | `.claude/rules/*.md` | Higher (overrides user rules) |

All `.md` files in these directories are **automatically loaded**. Project rules have the same priority as `.claude/CLAUDE.md`. More specific (project) instructions override broader (user) ones.

## File Structure

```markdown
---
paths:
  - "**/*.ts"
  - "src/components/**"
---

# Rule Title

Rule content here.
```

`paths` frontmatter is **optional**. Without it, the rule applies unconditionally.

## When to Use Rules vs CLAUDE.md

| Use CLAUDE.md for | Use rules/ for |
|-------------------|----------------|
| Project overview, key files, architecture | Focused behavioral standards |
| One-liner conventions | Anything >10 lines |
| Onboarding context | Domain-specific rules (security, testing, style) |

**Rule of thumb:** If a section in CLAUDE.md stands alone as a topic, it's a rule file candidate.

## Good Rule File Examples

```
.claude/rules/
  security.md           # no hardcoded secrets, input validation
  testing.md            # TDD workflow, coverage requirements
  git-workflow.md       # commit format, PR process
  coding-style.md       # naming, file size limits
  agents.md             # when to delegate to subagents
  frontend/
    components.md       # React patterns, component structure
    styling.md          # CSS/Tailwind conventions
  backend/
    api.md              # REST conventions, error responses
    database.md         # query patterns, migration rules
```

## Path-Scoped Rules

Apply rules only when working with matching files:

```markdown
---
paths:
  - "**/*.test.ts"
  - "**/*.spec.ts"
---

# Test File Standards

- Always use `describe`/`it` blocks
- Mock external dependencies at module boundary
- No `console.log` in tests
```

Glob patterns supported: `**/*.ts`, `src/**/*`, `*.md`, `src/components/*.tsx`

## Best Practices

- **One topic per file** — focused files are easier to maintain and reason about
- **Descriptive filenames** — `git-workflow.md` not `rules1.md`
- **Use `paths` sparingly** — only when the rule genuinely doesn't apply globally
- **Subdirectories for related sets** — `frontend/`, `backend/`, `infra/`
- **Keep rules actionable** — "Use ES modules" not "Consider ES modules"

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Duplicating CLAUDE.md content | Rules replace CLAUDE.md sections, not supplement |
| One giant rules file | Split by topic |
| Paths on universal rules | Remove `paths` if it applies everywhere |
| Vague rules ("write good code") | Concrete and specific ("max 200 lines per file") |
