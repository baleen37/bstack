# Datadog Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `datadog` plugin to the bstack repo that mirrors 5 curated skills from `DataDog/pup`'s `skills/` directory, aligned to bstack's frontmatter convention.

**Architecture:** Each mirrored skill is a single `SKILL.md` copied verbatim from upstream, with its `metadata` frontmatter block stripped so only `name` + `description` remain. The plugin follows the existing `plugins/<name>/{.claude-plugin/plugin.json, skills/*}` shape used by `jira` and `me`. Mirror provenance (upstream URL + commit SHA + curation rationale) is recorded in `plugins/datadog/SYNC.md`. The plugin is registered in the root `.claude-plugin/marketplace.json`.

**Tech Stack:** Markdown (SKILL.md), JSON (plugin.json, marketplace.json), Bash + BATS for tests, pre-commit hooks for lint. The `pup` CLI itself is a runtime dependency installed by the user, not vendored.

**Upstream reference:**
- Repository: https://github.com/DataDog/pup
- Commit SHA at time of mirror: `e3f0af522230608f44680656610afe6c4edf736f`
- Path: `skills/`

---

## File Structure

Files created in this plan:

- `plugins/datadog/.claude-plugin/plugin.json` — plugin manifest (name, version, description, author, license, keywords)
- `plugins/datadog/README.md` — user-facing overview, install instructions, auth, skill list
- `plugins/datadog/SYNC.md` — upstream provenance + sync procedure
- `plugins/datadog/skills/dd-pup/SKILL.md` — mirrored from upstream
- `plugins/datadog/skills/dd-logs/SKILL.md` — mirrored from upstream
- `plugins/datadog/skills/dd-monitors/SKILL.md` — mirrored from upstream
- `plugins/datadog/skills/dd-apm/SKILL.md` — mirrored from upstream
- `plugins/datadog/skills/dd-docs/SKILL.md` — mirrored from upstream

File modified in this plan:

- `.claude-plugin/marketplace.json` — append `datadog` entry to the `plugins` array

Each task below is one focused, committable unit.

---

## Task 0: Sparse-clone upstream into a scratch dir

**Files:**
- Working dir only: `/tmp/pup-mirror/`

This isn't a code change — it's a one-time setup step that gives subsequent tasks the source files to copy from. No commit.

- [ ] **Step 1: Clean any prior scratch dir and sparse-clone upstream at the recorded SHA**

Run:
```bash
rm -rf /tmp/pup-mirror
git clone --depth=1 --filter=blob:none --sparse https://github.com/DataDog/pup.git /tmp/pup-mirror
cd /tmp/pup-mirror && git sparse-checkout set skills && git checkout e3f0af522230608f44680656610afe6c4edf736f 2>/dev/null || git fetch --depth=1 origin e3f0af522230608f44680656610afe6c4edf736f && git checkout e3f0af522230608f44680656610afe6c4edf736f
```

If the specific SHA cannot be checked out (depth-1 clone limitation), do a full clone:
```bash
rm -rf /tmp/pup-mirror
git clone https://github.com/DataDog/pup.git /tmp/pup-mirror
cd /tmp/pup-mirror && git checkout e3f0af522230608f44680656610afe6c4edf736f
```

- [ ] **Step 2: Verify the 5 source skills exist**

Run:
```bash
for s in dd-pup dd-logs dd-monitors dd-apm dd-docs; do
  test -f "/tmp/pup-mirror/skills/$s/SKILL.md" && echo "OK $s" || echo "MISSING $s"
done
```
Expected: 5 lines all starting with `OK`.

- [ ] **Step 3: Record actual checkout SHA**

Run:
```bash
cd /tmp/pup-mirror && git rev-parse HEAD
```
Expected: `e3f0af522230608f44680656610afe6c4edf736f`. If different (upstream moved), update the SHA in Task 8 (SYNC.md) and at the top of this plan.

No commit for this task.

---

## Task 1: Create plugin.json

**Files:**
- Create: `plugins/datadog/.claude-plugin/plugin.json`

The bstack BATS suite (`tests/plugin_json.bats`) enforces: file must exist at `<plugin>/.claude-plugin/plugin.json`, be valid JSON, contain `name`, `description`, `author` fields, and `name` must match `^[a-z][a-z0-9-]*$`.

- [ ] **Step 1: Create the plugin manifest**

Create `plugins/datadog/.claude-plugin/plugin.json` with:
```json
{
  "name": "datadog",
  "version": "0.1.0",
  "description": "Datadog observability skills for Claude Code via the pup CLI - logs, monitors, APM, and docs lookup",
  "author": {
    "name": "baleen37",
    "email": "git@baleen.me"
  },
  "license": "MIT",
  "keywords": [
    "datadog",
    "observability",
    "monitoring",
    "logs",
    "apm",
    "pup"
  ]
}
```

- [ ] **Step 2: Validate JSON**

Run:
```bash
jq empty plugins/datadog/.claude-plugin/plugin.json && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add plugins/datadog/.claude-plugin/plugin.json
git commit -m "feat(datadog): add plugin manifest"
```

---

## Task 2: Mirror `dd-pup/SKILL.md` with stripped frontmatter

**Files:**
- Create: `plugins/datadog/skills/dd-pup/SKILL.md`

Mirror the body verbatim. Replace the upstream frontmatter (which contains `name`, `description`, and a `metadata:` block) with frontmatter containing only `name` and `description`. The `name` and `description` values are copied verbatim from upstream — do not paraphrase.

- [ ] **Step 1: Inspect the upstream frontmatter so you know which values to preserve**

Run:
```bash
awk '/^---$/{c++} c<2{print} c==2{exit}' /tmp/pup-mirror/skills/dd-pup/SKILL.md
```
This prints the upstream frontmatter (between the first two `---` lines). Note the `name:` and `description:` values exactly.

- [ ] **Step 2: Copy the body (everything after the closing `---`) into a temp file**

Run:
```bash
mkdir -p plugins/datadog/skills/dd-pup
awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-pup/SKILL.md > /tmp/dd-pup-body.md
head -3 /tmp/dd-pup-body.md
```
Expected: prints the first 3 lines of the upstream body (after the frontmatter), not `---` and not YAML.

- [ ] **Step 3: Assemble the mirrored file with stripped frontmatter**

Run:
```bash
{
  echo '---'
  echo 'name: dd-pup'
  echo 'description: Datadog CLI (pup). OAuth2 auth with token refresh.'
  echo '---'
  cat /tmp/dd-pup-body.md
} > plugins/datadog/skills/dd-pup/SKILL.md
```

The `description` value above must match what upstream's frontmatter has. If `awk` in Step 1 showed a different description, use that instead.

- [ ] **Step 4: Verify frontmatter is exactly two-field**

Run:
```bash
awk '/^---$/{c++; if(c==2) exit} c==1' plugins/datadog/skills/dd-pup/SKILL.md
```
Expected: prints exactly `---`, `name: dd-pup`, `description: ...` — no `metadata:` block.

- [ ] **Step 5: Verify the body is preserved**

Run:
```bash
diff <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-pup/SKILL.md) \
     <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' plugins/datadog/skills/dd-pup/SKILL.md)
```
Expected: no output (bodies match).

- [ ] **Step 6: Commit**

```bash
git add plugins/datadog/skills/dd-pup/SKILL.md
git commit -m "feat(datadog): mirror dd-pup skill from upstream"
```

---

## Task 3: Mirror `dd-logs/SKILL.md`

**Files:**
- Create: `plugins/datadog/skills/dd-logs/SKILL.md`

Same procedure as Task 2, for `dd-logs`. Procedure repeated here so this task is self-contained.

- [ ] **Step 1: Read upstream frontmatter**

Run:
```bash
awk '/^---$/{c++} c<2{print} c==2{exit}' /tmp/pup-mirror/skills/dd-logs/SKILL.md
```
Note the `description:` value (upstream had `Log management - search, pipelines, archives, and cost control.`).

- [ ] **Step 2: Extract body**

Run:
```bash
mkdir -p plugins/datadog/skills/dd-logs
awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-logs/SKILL.md > /tmp/dd-logs-body.md
```

- [ ] **Step 3: Assemble**

Run:
```bash
{
  echo '---'
  echo 'name: dd-logs'
  echo 'description: Log management - search, pipelines, archives, and cost control.'
  echo '---'
  cat /tmp/dd-logs-body.md
} > plugins/datadog/skills/dd-logs/SKILL.md
```

If Step 1 revealed a different description, substitute it.

- [ ] **Step 4: Verify frontmatter has no `metadata:` line**

Run:
```bash
awk '/^---$/{c++; if(c==2) exit} c==1' plugins/datadog/skills/dd-logs/SKILL.md | grep -c '^metadata:'
```
Expected: `0`.

- [ ] **Step 5: Verify body matches upstream**

Run:
```bash
diff <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-logs/SKILL.md) \
     <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' plugins/datadog/skills/dd-logs/SKILL.md)
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add plugins/datadog/skills/dd-logs/SKILL.md
git commit -m "feat(datadog): mirror dd-logs skill from upstream"
```

---

## Task 4: Mirror `dd-monitors/SKILL.md`

**Files:**
- Create: `plugins/datadog/skills/dd-monitors/SKILL.md`

Same procedure. Upstream description: `Monitor management - create, update, mute, and alerting best practices.`

- [ ] **Step 1: Read upstream frontmatter**

Run:
```bash
awk '/^---$/{c++} c<2{print} c==2{exit}' /tmp/pup-mirror/skills/dd-monitors/SKILL.md
```

- [ ] **Step 2: Extract body**

Run:
```bash
mkdir -p plugins/datadog/skills/dd-monitors
awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-monitors/SKILL.md > /tmp/dd-monitors-body.md
```

- [ ] **Step 3: Assemble**

Run:
```bash
{
  echo '---'
  echo 'name: dd-monitors'
  echo 'description: Monitor management - create, update, mute, and alerting best practices.'
  echo '---'
  cat /tmp/dd-monitors-body.md
} > plugins/datadog/skills/dd-monitors/SKILL.md
```

- [ ] **Step 4: Verify no `metadata:` field**

Run:
```bash
awk '/^---$/{c++; if(c==2) exit} c==1' plugins/datadog/skills/dd-monitors/SKILL.md | grep -c '^metadata:'
```
Expected: `0`.

- [ ] **Step 5: Verify body matches upstream**

Run:
```bash
diff <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-monitors/SKILL.md) \
     <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' plugins/datadog/skills/dd-monitors/SKILL.md)
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add plugins/datadog/skills/dd-monitors/SKILL.md
git commit -m "feat(datadog): mirror dd-monitors skill from upstream"
```

---

## Task 5: Mirror `dd-apm/SKILL.md`

**Files:**
- Create: `plugins/datadog/skills/dd-apm/SKILL.md`

Upstream description: `APM - traces, services, dependencies, performance analysis.`

- [ ] **Step 1: Read upstream frontmatter**

Run:
```bash
awk '/^---$/{c++} c<2{print} c==2{exit}' /tmp/pup-mirror/skills/dd-apm/SKILL.md
```

- [ ] **Step 2: Extract body**

Run:
```bash
mkdir -p plugins/datadog/skills/dd-apm
awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-apm/SKILL.md > /tmp/dd-apm-body.md
```

- [ ] **Step 3: Assemble**

Run:
```bash
{
  echo '---'
  echo 'name: dd-apm'
  echo 'description: APM - traces, services, dependencies, performance analysis.'
  echo '---'
  cat /tmp/dd-apm-body.md
} > plugins/datadog/skills/dd-apm/SKILL.md
```

- [ ] **Step 4: Verify no `metadata:` field**

Run:
```bash
awk '/^---$/{c++; if(c==2) exit} c==1' plugins/datadog/skills/dd-apm/SKILL.md | grep -c '^metadata:'
```
Expected: `0`.

- [ ] **Step 5: Verify body matches upstream**

Run:
```bash
diff <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-apm/SKILL.md) \
     <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' plugins/datadog/skills/dd-apm/SKILL.md)
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add plugins/datadog/skills/dd-apm/SKILL.md
git commit -m "feat(datadog): mirror dd-apm skill from upstream"
```

---

## Task 6: Mirror `dd-docs/SKILL.md`

**Files:**
- Create: `plugins/datadog/skills/dd-docs/SKILL.md`

Upstream description: `Datadog docs lookup using docs.datadoghq.com/llms.txt and linked Markdown pages.`

- [ ] **Step 1: Read upstream frontmatter**

Run:
```bash
awk '/^---$/{c++} c<2{print} c==2{exit}' /tmp/pup-mirror/skills/dd-docs/SKILL.md
```

- [ ] **Step 2: Extract body**

Run:
```bash
mkdir -p plugins/datadog/skills/dd-docs
awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-docs/SKILL.md > /tmp/dd-docs-body.md
```

- [ ] **Step 3: Assemble**

Run:
```bash
{
  echo '---'
  echo 'name: dd-docs'
  echo 'description: Datadog docs lookup using docs.datadoghq.com/llms.txt and linked Markdown pages.'
  echo '---'
  cat /tmp/dd-docs-body.md
} > plugins/datadog/skills/dd-docs/SKILL.md
```

- [ ] **Step 4: Verify no `metadata:` field**

Run:
```bash
awk '/^---$/{c++; if(c==2) exit} c==1' plugins/datadog/skills/dd-docs/SKILL.md | grep -c '^metadata:'
```
Expected: `0`.

- [ ] **Step 5: Verify body matches upstream**

Run:
```bash
diff <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' /tmp/pup-mirror/skills/dd-docs/SKILL.md) \
     <(awk 'BEGIN{c=0} /^---$/{c++; next} c>=2{print}' plugins/datadog/skills/dd-docs/SKILL.md)
```
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add plugins/datadog/skills/dd-docs/SKILL.md
git commit -m "feat(datadog): mirror dd-docs skill from upstream"
```

---

## Task 7: Add README.md

**Files:**
- Create: `plugins/datadog/README.md`

User-facing entry doc: one-line description, install, auth, included skills, upstream attribution.

- [ ] **Step 1: Write the README**

Create `plugins/datadog/README.md`:
````markdown
# datadog

Datadog observability skills for Claude Code, powered by the [`pup`](https://github.com/DataDog/pup) CLI.

## Prerequisites

Install `pup`:

```bash
brew tap datadog-labs/pack && brew install datadog-labs/pack/pup
```

Other install options (cargo, prebuilt binaries) are documented at https://github.com/DataDog/pup.

## Authentication

Recommended — OAuth2 (browser-based, secure token storage):

```bash
pup auth login
```

Alternative — API key via environment variables:

```bash
export DD_API_KEY=...
export DD_APP_KEY=...
export DD_SITE=datadoghq.com   # or datadoghq.eu, etc.
```

## Included Skills

| Skill | Purpose |
|---|---|
| `dd-pup` | Core pup CLI auth, command structure, output formats |
| `dd-logs` | Log search, pipelines, archives, cost control |
| `dd-monitors` | Monitor create/update/mute, alerting best practices |
| `dd-apm` | APM traces, services, dependencies, performance |
| `dd-docs` | Datadog docs lookup via `docs.datadoghq.com/llms.txt` |

## Upstream

Skill bodies are mirrored verbatim from [`DataDog/pup`](https://github.com/DataDog/pup) (`skills/` directory). Only the frontmatter is adjusted to match bstack's `name` + `description` convention. See `SYNC.md` for the upstream commit SHA and re-sync procedure.
````

- [ ] **Step 2: Commit**

```bash
git add plugins/datadog/README.md
git commit -m "feat(datadog): add README with install and auth instructions"
```

---

## Task 8: Add SYNC.md

**Files:**
- Create: `plugins/datadog/SYNC.md`

Records the upstream provenance and the procedure for re-syncing when upstream updates.

- [ ] **Step 1: Write SYNC.md**

Create `plugins/datadog/SYNC.md`:
````markdown
# Upstream Sync

## Source

- Repository: https://github.com/DataDog/pup
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
2. Frontmatter — only `name:` and `description:` are kept. Both values are copied verbatim from upstream. The upstream `metadata:` block (version, author, repository, tags, globs, alwaysApply) is removed to match the bstack convention used by other plugins.

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
````

- [ ] **Step 2: Commit**

```bash
git add plugins/datadog/SYNC.md
git commit -m "docs(datadog): record upstream provenance and sync procedure"
```

---

## Task 9: Register plugin in marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json` (append to `plugins` array)

The bstack BATS suite (`tests/marketplace_json.bats`) enforces: `marketplace_all_plugins_listed` — every directory under `plugins/` must have an entry in `marketplace.json`. Adding `plugins/datadog/` without updating `marketplace.json` would fail the suite.

- [ ] **Step 1: Inspect the existing array shape**

Run:
```bash
jq '.plugins[0]' .claude-plugin/marketplace.json
```
Expected: prints an object with `name`, `description`, `source`, `category`, `tags`, `version` fields. The new entry mirrors this shape.

- [ ] **Step 2: Append the datadog entry**

The current file ends with a closing `]` for `plugins` and `}` for the root object. Use `jq` to append rather than hand-editing the JSON, which avoids comma/whitespace mistakes:

```bash
jq '.plugins += [{
  "name": "datadog",
  "description": "Datadog observability skills for Claude Code via the pup CLI",
  "source": "./plugins/datadog",
  "category": "development",
  "tags": ["datadog", "observability", "monitoring", "logs", "apm", "pup"],
  "version": "0.1.0"
}]' .claude-plugin/marketplace.json > /tmp/marketplace.json.new
mv /tmp/marketplace.json.new .claude-plugin/marketplace.json
```

- [ ] **Step 3: Verify JSON validity and presence**

Run:
```bash
jq empty .claude-plugin/marketplace.json && \
jq -r '.plugins[] | select(.name=="datadog") | .source' .claude-plugin/marketplace.json
```
Expected: `./plugins/datadog`.

- [ ] **Step 4: Verify the new source path exists**

Run:
```bash
test -d plugins/datadog && test -f plugins/datadog/.claude-plugin/plugin.json && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(datadog): register plugin in marketplace"
```

---

## Task 10: Run BATS suite

**Files:** None modified — verification only.

The bstack suite covers `plugin_json.bats`, `marketplace_json.bats`, `frontmatter_tests.bats` — all of which now have the datadog plugin in their scope.

- [ ] **Step 1: Run the suite**

Run:
```bash
bats tests/
```
Expected: all tests pass. Specifically, these previously-existing tests now also cover the new plugin:
- `all plugins have plugin.json` — passes because Task 1 created it
- `all plugin.json files are valid JSON` — passes (jq verified in Task 1)
- `all plugin.json files have required fields` — passes (name, description, author present)
- `all plugin.json names follow naming convention` — passes (`datadog` matches `^[a-z][a-z0-9-]*$`)
- `marketplace.json includes all plugins in plugins/ directory` — passes because Task 9 registered it
- `SKILL.md files have name field` — passes for all 5 mirrored skills
- `SKILL.md files have description field` — passes for all 5 mirrored skills

- [ ] **Step 2: If anything fails, fix it before moving on**

Read the BATS failure message, identify which task introduced the regression, fix it, re-run `bats tests/`. Do not skip this task.

No commit (verification only). If a fix was needed, that fix gets its own commit in the relevant task's amended workflow — or, if the fix is small and orthogonal, a separate `fix(datadog):` commit.

---

## Task 11: Run pre-commit on the new files

**Files:** None modified — verification only.

The `.pre-commit-config.yaml` runs markdownlint, yaml, JSON, shellcheck.

- [ ] **Step 1: Run pre-commit against the changed files**

Run:
```bash
pre-commit run --files \
  plugins/datadog/.claude-plugin/plugin.json \
  plugins/datadog/README.md \
  plugins/datadog/SYNC.md \
  plugins/datadog/skills/dd-pup/SKILL.md \
  plugins/datadog/skills/dd-logs/SKILL.md \
  plugins/datadog/skills/dd-monitors/SKILL.md \
  plugins/datadog/skills/dd-apm/SKILL.md \
  plugins/datadog/skills/dd-docs/SKILL.md \
  .claude-plugin/marketplace.json
```
Expected: all checks pass.

- [ ] **Step 2: If markdownlint flags the mirrored SKILL.md files**

The skill bodies are upstream content and should not be edited to satisfy lint. If pre-commit flags them:
- For trivial auto-fixes (trailing whitespace, final newline) that pre-commit applies automatically: accept, re-stage, commit with `chore(datadog): apply pre-commit auto-fixes to mirrored skills`.
- For structural lint failures (heading levels, line length): add an entry to `.markdownlint.yaml` (or whatever lint config the repo uses — inspect first) excluding `plugins/datadog/skills/**` from the offending rule, with a comment pointing to `plugins/datadog/SYNC.md` explaining why. Commit as `chore(datadog): exclude mirrored skill bodies from markdownlint rule X`.

Do not paraphrase or restructure upstream content to satisfy lint — that breaks the mirror's verbatim contract.

---

## Task 12: Final smoke test

**Files:** None modified — verification only.

- [ ] **Step 1: List the final tree of the new plugin**

Run:
```bash
find plugins/datadog -type f | sort
```
Expected:
```
plugins/datadog/.claude-plugin/plugin.json
plugins/datadog/README.md
plugins/datadog/SYNC.md
plugins/datadog/skills/dd-apm/SKILL.md
plugins/datadog/skills/dd-docs/SKILL.md
plugins/datadog/skills/dd-logs/SKILL.md
plugins/datadog/skills/dd-monitors/SKILL.md
plugins/datadog/skills/dd-pup/SKILL.md
```

- [ ] **Step 2: Confirm marketplace entry and source exist together**

Run:
```bash
jq -r '.plugins[] | select(.name=="datadog")' .claude-plugin/marketplace.json && \
test -d plugins/datadog && echo "OK plugin registered and present"
```
Expected: prints the datadog entry, then `OK plugin registered and present`.

- [ ] **Step 3: Confirm none of the mirrored SKILL.md files have a stale `metadata:` field**

Run:
```bash
for f in plugins/datadog/skills/*/SKILL.md; do
  echo "=== $f ==="
  awk '/^---$/{c++; if(c==2) exit} c==1' "$f"
done
```
Expected: each file shows `---` then `name: dd-...` then `description: ...` and nothing else inside the frontmatter.

- [ ] **Step 4: Confirm pup install instructions are correct**

Run:
```bash
grep -F 'brew tap datadog-labs/pack && brew install datadog-labs/pack/pup' plugins/datadog/README.md
```
Expected: matches one line.

No commit. Plan complete.

---

## Notes

- **Why one task per mirrored skill** rather than a single "mirror all 5" task: keeps each commit small and reviewable, so a defect in one mirror (wrong description, accidentally edited body) is bisectable and easy to revert without disturbing the others.
- **Why `jq`-based marketplace.json edit** rather than manual edit: avoids whitespace/comma errors and is easier to review (diff shows exactly the appended object).
- **Why `diff` against upstream body in each mirror task**: enforces the "verbatim body" contract. If a future re-sync changes upstream and someone forgets to run this check, the body could silently drift.
- **No tests added for the new plugin** beyond what the existing BATS suite already covers. The existing suite (`plugin_json.bats`, `marketplace_json.bats`, `frontmatter_tests.bats`) is generic — it finds and checks every plugin under `plugins/`, so it automatically covers `datadog`. Adding plugin-specific tests would be premature.
