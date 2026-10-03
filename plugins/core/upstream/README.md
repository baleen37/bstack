# Upstream provenance

`core` adapts the following MIT-licensed skill snapshots. Their original package
READMEs and metadata are kept here as historical records, not installation
instructions. Upstream URLs and license notices remain unchanged.

| Source | Snapshot | Preserved notices |
| --- | --- | --- |
| [obra/superpowers](https://github.com/obra/superpowers/tree/8ca22db) | `8ca22db` (v6.4.2) | [README](superpower/README.md), [metadata](superpower/metadata.json), [MIT license](superpower/LICENSE) |
| [mattpocock/skills](https://github.com/mattpocock/skills/tree/d81f3a1) | `d81f3a1` (2026-09-29) | [README](mattpocock-skills/README.md), [metadata](mattpocock-skills/metadata.json), [MIT license](mattpocock-skills/LICENSE) |

## Local adaptations

All distributed skills live in `../skills/` and use the `core:` namespace.
The former design/execution and Matt engineering packages are no longer
marketplace entries. Their names are not compatibility aliases.

Grilling is a brainstorming reference; PR writing is a create-pr reference
(with [Humanlayer credits](../skills/create-pr/references/CREDITS.md)); teaching
uses learn's topic workspace. The router, setup, bootstrap, workflow diagnosis,
and spec writer have local names and one shared development flow. Specs save
under `docs/specs/` by default; tracker publication is optional.

Previously maintained fixes remain: task-done validates commit ranges and
handles silent successful tests; helpers are invoked through bash; the visual
server does not load the remote logo; sdd-workspace neutralizes CDPATH. Script
bodies and runtime environment variables are preserved during this integration.
