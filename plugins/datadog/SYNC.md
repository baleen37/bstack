# Upstream Sync

## Source

- Repository: <https://github.com/DataDog/pup>
- Path within repo: `skills/`
- Mirrored at commit: `e3f0af522230608f44680656610afe6c4edf736f`

## Mirrored Skills

| Skill | Upstream path |
|---|---|
| `dd-pup` | `skills/dd-pup/SKILL.md` |
| `dd-logs` | `skills/dd-logs/SKILL.md` |
| `dd-monitors` | `skills/dd-monitors/SKILL.md` |
| `dd-apm` | `skills/dd-apm/SKILL.md` |
| `dd-docs` | `skills/dd-docs/SKILL.md` |

## Skills Intentionally Not Mirrored

| Skill | Reason |
|---|---|
| `dd-debugger` | Live Debugger probes — only relevant when actively placing runtime probes on production services |
| `dd-symdb` | Symbol Database — pairs with `dd-debugger`, same scope |
| `dd-code-generation` | 551 lines, focused on generating Datadog SDK integration code; out of scope for current needs |
| `dd-file-issue` | Meta-tooling for filing GitHub issues against pup itself |

Revisit these when the corresponding workflows become relevant.

## Transformation Rules

Each mirrored `SKILL.md`:

1. Body — copied verbatim from upstream (everything after the closing `---` of the frontmatter).
   Trailing whitespace and end-of-file newlines are normalized by pre-commit hooks; this is
   a cosmetic-only divergence from upstream.
2. Frontmatter — only `name:` and `description:` are kept. Both values are copied verbatim
   from upstream. The upstream `metadata:` block (version, author, repository, tags, globs,
   alwaysApply) is removed to match the bstack convention used by other plugins.

## Re-sync Procedure

```bash
# 1. Fetch upstream at a new SHA
rm -rf /tmp/pup-mirror
git clone https://github.com/DataDog/pup.git /tmp/pup-mirror
cd /tmp/pup-mirror && git checkout <new-sha>

# 2. For each mirrored skill, regenerate SKILL.md:
#    - Read upstream frontmatter (awk between first two `---`)
#    - Extract body (everything after the second `---`)
#    - Assemble new SKILL.md with frontmatter containing only `name:` and `description:`
#      (values copied verbatim from upstream)
# 3. Update the "Mirrored at commit" SHA above
# 4. Run `bats tests/` to confirm nothing broke
# 5. Commit
```
