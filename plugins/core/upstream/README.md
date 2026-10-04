# Upstream provenance

`core` adapts the following MIT-licensed skill snapshot. Its original package
README and metadata are kept here as historical records, not installation
instructions. Upstream URLs and license notices remain unchanged.

| Source | Snapshot | Preserved notices |
| --- | --- | --- |
| [mattpocock/skills](https://github.com/mattpocock/skills/tree/d81f3a1) | `d81f3a1` (2026-09-29) | [README](mattpocock-skills/README.md), [metadata](mattpocock-skills/metadata.json), [MIT license](mattpocock-skills/LICENSE) |

## Local adaptations

All distributed skills live in `../skills/` and use the `core:` namespace.
Upstream `/skill` invocations are rewritten to `core:skill`.

Matt's flow skills are not packaged: `ask-matt`, `grilling`, `grill-me`,
`grill-with-docs`, `to-spec`, `to-tickets`, `implement`, `implement-spec`,
`wayfinder`, `setup-matt-pocock-skills`, and `triage`. Renamed skills:

- `teach` → `learn` (workspace under `~/.skills/learn/<topic>/`)
- `pr` → a `create-pr` reference
  (with [Humanlayer credits](../skills/create-pr/references/CREDITS.md))
- upstream `code-review` is not packaged; references resolve to the local `core:code-review`

obra/superpowers skills are not part of `core`; they ship as the separate
[`superpower`](../../superpower/README.md) plugin.
