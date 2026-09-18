# Story Loop Skills Design

## Goal

Add the upstream `story-loop` workflow and `e2e-scenario-testing` guidance to
the personal `me` plugin so both Claude Code and Codex can discover them.

## Shape

- Add `plugins/me/skills/e2e-scenario-testing/SKILL.md`, preserving the
  upstream scenario-card format, real-interface recipes, evidence rules, and
  cleanup discipline.
- Add `plugins/me/skills/story-loop/SKILL.md`, adapting the upstream Claude
  command into a provider-neutral skill. Scope comes from the user's request;
  no scope means the whole repository.
- Keep the existing `e2e` skill unchanged. It verifies a selected
  cross-component flow, while `e2e-scenario-testing` defines reusable
  real-interface scenario cards and `story-loop` inventories an entire scope
  and drives the cards through verification.
- List both additions in `plugins/me/README.md`.

## Adaptation Rules

- Remove Claude-command-only frontmatter and `$ARGUMENTS` syntax from
  `story-loop`.
- Keep the canonical ledger single-writer rule and the
  `test -> fix -> re-test` lifecycle.
- Put runner delegation and ledger orchestration directly in `story-loop`.
  Do not claim that `e2e-scenario-testing` contains runner templates or
  per-run ledgers that its current public source does not provide.
- Preserve explicit checkpoints, the three-iteration safety cap, and honest
  reporting of skipped or untestable behavior.
- Make no changes to product code, existing skills, plugin manifests, or
  release versions.

## Verification

- Validate both skill directories with the repository's skill validator.
- Run markdown lint on the two skills, this design, and the updated README.
- Run the existing plugin-loading and cross-plugin structural tests.
- Run `git diff --check` and inspect the final diff for scope.
