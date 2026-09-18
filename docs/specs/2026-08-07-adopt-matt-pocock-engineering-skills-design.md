# Adopt Matt Pocock Engineering Skills

## Goal

Add the upstream engineering skills from `mattpocock/skills` to the `me` plugin without adapting their content to bstack conventions.

## Scope

Copy the upstream snapshot at commit `84fdeffd12f2ee307994d1eb6feb48173b6e0502` into `plugins/me/skills/`:

- `grill-with-docs`
- `domain-modeling`
- `grilling`
- `code-review`
- `to-tickets`
- `research`, replacing the existing `plugins/me/skills/research/SKILL.md`
- `handoff`, replacing the existing `plugins/me/skills/handoff/SKILL.md`

The transitive skills are included because the requested skills invoke or reference them. Their upstream file contents remain unchanged.

## Non-goals

- Do not rewrite upstream instructions for bstack, Jira, Notion, Claude, or Codex.
- Do not create `CONTEXT.md`, ADRs, issue-tracker configuration, or ticket files during installation.
- Do not remove the existing research evaluator files; they remain untouched even though the upstream `research/SKILL.md` no longer references them.
- Remove only the obsolete bstack-specific handoff skill-contract test and fixture that assert behavior absent from the accepted upstream handoff.
- Do not modify unrelated skills or plugin behavior.

## Packaging

Place the copied files under `plugins/me/skills/`, add the skills to the user-facing `plugins/me/README.md`, then regenerate Codex artifacts with the repository's synchronization script. The generated files are not edited directly.

## Verification

- Compare copied source files against the pinned upstream snapshot by SHA-256.
- Run `bun run sync:codex` and `bun run check:codex`.
- Run plugin-loading and cross-plugin structural tests.
- Run `git diff --check`.
