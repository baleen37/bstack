# superpower plugin

This plugin packages obra's Superpowers skills under the `superpower` name.

- Upstream: <https://github.com/obra/superpowers>
- Snapshot: `8ca22db` (v6.4.2)
- Skill files are preserved except for these renames:
  - `superpowers:` skill prefix → `superpower:`
  - `docs/superpowers/specs`, `docs/superpowers/plans` → `docs/specs`, `docs/plans`
  - `.superpowers/` state directories → `.bstack/`
  - `using-superpowers`, `diagnosing-superpowers` → `using-superpower`, `diagnosing-superpower`
- Upstream URLs are kept as-is.
- Local fixes kept from the earlier `me` fork:
  - `executing-plans/scripts/task-done` rejects an empty or foreign commit range
    and tolerates a test command with no output.
  - `executing-plans` runs its helper scripts through `bash`.
  - `brainstorming/scripts/server.cjs` never loads the remote brand logo.
  - `subagent-driven-development/scripts/sdd-workspace` uses `CDPATH=''` (ShellCheck).

`test-driven-development` and `systematic-debugging` are not packaged because
they overlap with `mattpocock-skills`; references to them point to
`mattpocock-skills:tdd` and `mattpocock-skills:diagnosing-bugs`.
