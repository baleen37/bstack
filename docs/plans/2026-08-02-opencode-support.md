# OpenCode Support Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Generate, verify, and install OpenCode artifacts (skills, agents, command, plugin) from the Claude Code source of truth, mirroring the existing Codex pipeline.

**Architecture:** Claude Code metadata in `.claude-plugin/marketplace.json` stays the source of truth. A bash generator (`scripts/generate-opencode-artifacts.sh`) produces a committed `.opencode/` bundle (skills copied, agents/command frontmatter-converted, a commit-guard `plugin.ts`). A drift-check script guards it in CI, a symlink script installs it to `~/.config/opencode/`, and `.releaserc.js` syncs it on release.

**Tech Stack:** bash, jq, awk, TypeScript (Bun-run opencode plugin), BATS, semantic-release.

Reference design: `docs/plans/2026-08-02-opencode-support-design.md`

---

## Facts the executor needs

- Eligible plugins = every `.plugins[].source` entry in `.claude-plugin/marketplace.json` stripped of `./plugins/` prefix (currently `me`, `datadog`, `autoresearch`; all three have skills).
- Skill inventory: `me` (competitive-agents, create-pr, e2e-scenario-testing, handoff, research, ship, story-loop, verify, write-skill, writing-prds, writing-rfcs), `datadog` (datadog), `autoresearch` (autoresearch). 13 total, no name collisions.
- Agents: `plugins/me/agents/{code-reviewer,researcher,security-auditor,test-engineer}.md`. Frontmatter has `model: sonnet` or `model: inherit`.
- Command: `plugins/autoresearch/commands/autoresearch.md` with frontmatter keys `description`, `argument-hint`, `allowed-tools`.
- `$CLAUDE_PLUGIN_ROOT` is referenced in `plugins/me/skills/create-pr/SKILL.md:9`. The plugin injects it via `shell.env`.
- Scripts use the same conventions as the codex scripts: `set -euo pipefail`, `PROJECT_ROOT` resolution, atomic `mktemp`+`cmp` writes.

---

## Task 1: bstack.ts plugin template

**Files:**
- Create: `scripts/opencode-plugin/bstack.ts`

**Step 1: Write the plugin template**

```ts
const PLUGIN_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "")

const BLOCKS: Array<{ pattern: RegExp; message: string; info?: string }> = [
  {
    pattern: /git\s+commit.*--no-verify/,
    message: "--no-verify is not allowed in this repository",
    info: "Please use 'git commit' without --no-verify. All commits must pass quality checks.",
  },
  { pattern: /git\s+.*skip.*hooks/, message: "Skipping hooks is not allowed" },
  { pattern: /git\s+.*--no-.*hook/, message: "Hook bypass is not allowed" },
  { pattern: /HUSKY=0.*git/, message: "HUSKY=0 bypass is not allowed" },
  { pattern: /SKIP_HOOKS=.*git/, message: "SKIP_HOOKS bypass is not allowed" },
  { pattern: /git\s+update-ref/, message: "git update-ref is not allowed in this repository", info: "This command can bypass commit hooks." },
  { pattern: /git\s+filter-branch/, message: "git filter-branch is not allowed in this repository", info: "This command can rewrite history and bypass hooks." },
  { pattern: /git\s+config.*core\.hooksPath/, message: "Modifying core.hooksPath is not allowed in this repository", info: "This can disable commit hooks." },
]

const isGitCommand = (command: string): boolean => /^\s*(\S*=\S*\s+)*git\s+/.test(command)

export const Bstack = async () => {
  return {
    "tool.execute.before": async (
      input: { tool: string },
      output: { args?: { command?: string } },
    ) => {
      if (input.tool !== "bash") return
      const command = output.args?.command ?? ""
      if (!isGitCommand(command)) return

      for (const block of BLOCKS) {
        if (block.pattern.test(command)) {
          throw new Error(block.info ? `${block.message}\n${block.info}` : block.message)
        }
      }

      if (/git\s+commit/.test(command) && /Co-Authored-By:/.test(command)) {
        throw new Error("Co-Authored-By trailers are not allowed in commit messages\nPlease remove 'Co-Authored-By:' from your commit message.")
      }
    },
    "shell.env": async (_input: unknown, output: { env: Record<string, string> }) => {
      if (!output.env.CLAUDE_PLUGIN_ROOT) {
        output.env.CLAUDE_PLUGIN_ROOT = PLUGIN_ROOT
      }
    },
  }
}
```

**Step 2: Verify syntax**

Run: `bun -e 'const m = await import("./scripts/opencode-plugin/bstack.ts"); if (typeof m.Bstack !== "function") throw new Error("no Bstack export")'`
Expected: no output (exit 0).

**Step 3: Commit**

```bash
git add scripts/opencode-plugin/bstack.ts
git commit -m "feat(opencode): add bstack plugin template"
```

---

## Task 2: Artifact generator script

**Files:**
- Create: `scripts/generate-opencode-artifacts.sh`
- Create: `scripts/sync-opencode-artifacts.sh`

**Step 1: Write `scripts/generate-opencode-artifacts.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CLAUDE_MARKETPLACE="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
PLUGINS_ROOT="${PROJECT_ROOT}/plugins"
OPENCODE_ROOT="${PROJECT_ROOT}/.opencode"

eligible_plugins() {
  jq -r '.plugins[].source' "${CLAUDE_MARKETPLACE}" | sed 's|^\./plugins/||'
}

convert_agent() {
  awk '
    BEGIN { infm = 0; closed = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !closed {
      if ($0 == "---") {
        print "mode: subagent"
        closed = 1
        print
        next
      }
      if ($0 ~ /^model:/) { next }
      print
      next
    }
    { print }
  ' "$1"
}

convert_command() {
  awk '
    BEGIN { infm = 0; closed = 0; skip = 0 }
    NR == 1 && $0 == "---" { infm = 1; print; next }
    infm && !closed {
      if ($0 == "---") { closed = 1; print; next }
      if (skip && $0 ~ /^[^[:space:]]/) { skip = 0 }
      if (skip) { next }
      if ($0 ~ /^(argument-hint|allowed-tools):/) { skip = 1; next }
      print
      next
    }
    { print }
  ' "$1"
}

tmp_root="$(mktemp -d "${OPENCODE_ROOT}.tmp.XXXXXX")"
trap 'rm -rf "${tmp_root}"' EXIT

mkdir -p "${tmp_root}/skills" "${tmp_root}/agents" "${tmp_root}/command" "${tmp_root}/plugins"

generated_any=0

while IFS= read -r plugin_name; do
  [ -n "${plugin_name}" ] || continue
  plugin_dir="${PLUGINS_ROOT}/${plugin_name}"
  [ -d "${plugin_dir}" ] || continue

  if [ -d "${plugin_dir}/skills" ]; then
    for skill_dir in "${plugin_dir}"/skills/*/; do
      [ -d "${skill_dir}" ] || continue
      skill_name="$(basename "${skill_dir}")"
      target="${tmp_root}/skills/${skill_name}"
      if [ -e "${target}" ]; then
        echo "Skill name collision: ${skill_name}" >&2
        exit 1
      fi
      cp -R "${skill_dir}" "${target}"
    done
  fi

  if [ -d "${plugin_dir}/agents" ]; then
    for agent_file in "${plugin_dir}"/agents/*.md; do
      [ -f "${agent_file}" ] || continue
      convert_agent "${agent_file}" > "${tmp_root}/agents/$(basename "${agent_file}")"
    done
  fi

  if [ -d "${plugin_dir}/commands" ]; then
    for cmd_file in "${plugin_dir}"/commands/*.md; do
      [ -f "${cmd_file}" ] || continue
      convert_command "${cmd_file}" > "${tmp_root}/command/$(basename "${cmd_file}")"
    done
  fi

  generated_any=1
done < <(eligible_plugins)

cp "${SCRIPT_DIR}/opencode-plugin/bstack.ts" "${tmp_root}/plugins/bstack.ts"

if [ "${generated_any}" -eq 1 ]; then
  rm -rf "${OPENCODE_ROOT}"
  mv "${tmp_root}" "${OPENCODE_ROOT}"
  trap - EXIT
fi
```

**Step 2: Write `scripts/sync-opencode-artifacts.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

bash "${SCRIPT_DIR}/generate-opencode-artifacts.sh"
```

**Step 3: Make scripts executable and run**

Run: `chmod +x scripts/generate-opencode-artifacts.sh scripts/sync-opencode-artifacts.sh && bash scripts/sync-opencode-artifacts.sh`
Expected: `.opencode/` created. Verify:
- `ls .opencode/skills | wc -l` → `13`
- `ls .opencode/agents` → 4 agent files; `grep -c '^mode: subagent$' .opencode/agents/code-reviewer.md` → `1`; `grep -cE '^model:' .opencode/agents/code-reviewer.md` → `0`
- `grep -cE '^(argument-hint|allowed-tools):' .opencode/command/autoresearch.md` → `0`
- `test -f .opencode/plugins/bstack.ts` → ok

**Step 4: Commit**

```bash
git add scripts/generate-opencode-artifacts.sh scripts/sync-opencode-artifacts.sh .opencode
git commit -m "feat(opencode): generate opencode artifacts"
```

---

## Task 3: Drift check script and package.json wiring

**Files:**
- Create: `scripts/check-opencode-artifacts.sh`
- Modify: `package.json` (scripts block)

**Step 1: Write `scripts/check-opencode-artifacts.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

bash "${SCRIPT_DIR}/sync-opencode-artifacts.sh"

cd "${PROJECT_ROOT}"

git diff --exit-code -- .opencode

untracked_artifacts="$(
  git ls-files --others --exclude-standard -- .opencode
)"

if [ -n "${untracked_artifacts}" ]; then
  echo "Untracked OpenCode artifacts found:" >&2
  echo "${untracked_artifacts}" >&2
  exit 1
fi
```

**Step 2: Add package.json scripts**

Add to `"scripts"` in `package.json`:

```json
"sync:opencode": "bash scripts/sync-opencode-artifacts.sh",
"check:opencode": "bash scripts/check-opencode-artifacts.sh",
"install:opencode": "bash scripts/install-opencode.sh"
```

Note: `install:opencode` target is created in Task 5; until then the script is absent. Add the package.json line now and the script in Task 5.

**Step 3: Verify drift check passes**

Run: `chmod +x scripts/check-opencode-artifacts.sh && bash scripts/check-opencode-artifacts.sh`
Expected: exit 0, no output.

**Step 4: Commit**

```bash
git add scripts/check-opencode-artifacts.sh package.json
git commit -m "feat(opencode): add drift check and npm scripts"
```

---

## Task 4: Install script

**Files:**
- Create: `scripts/install-opencode.sh`

**Step 1: Write `scripts/install-opencode.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
OPENCODE_ROOT="${PROJECT_ROOT}/.opencode"
CONFIG_ROOT="${OPENCODE_CONFIG_DIR:-${HOME}/.config/opencode}"

if [ ! -d "${OPENCODE_ROOT}" ]; then
  echo "Missing ${OPENCODE_ROOT}; run 'bun run sync:opencode' first" >&2
  exit 1
fi

mkdir -p "${CONFIG_ROOT}/skills" "${CONFIG_ROOT}/agents" "${CONFIG_ROOT}/command" "${CONFIG_ROOT}/plugins"

for skill_dir in "${OPENCODE_ROOT}"/skills/*; do
  [ -d "${skill_dir}" ] || continue
  ln -sfn "${skill_dir}" "${CONFIG_ROOT}/skills/$(basename "${skill_dir}")"
done

for agent_file in "${OPENCODE_ROOT}"/agents/*.md; do
  [ -f "${agent_file}" ] || continue
  ln -sfn "${agent_file}" "${CONFIG_ROOT}/agents/$(basename "${agent_file}")"
done

for cmd_file in "${OPENCODE_ROOT}"/command/*.md; do
  [ -f "${cmd_file}" ] || continue
  ln -sfn "${cmd_file}" "${CONFIG_ROOT}/command/$(basename "${cmd_file}")"
done

ln -sfn "${OPENCODE_ROOT}/plugins/bstack.ts" "${CONFIG_ROOT}/plugins/bstack.ts"

echo "Installed OpenCode artifacts into ${CONFIG_ROOT}"
```

**Step 2: Verify install (dry, uses real global config)**

Run: `chmod +x scripts/install-opencode.sh && OPENCODE_CONFIG_DIR="$(mktemp -d)" bash scripts/install-opencode.sh`
Expected: prints install path; target dir contains symlinked `skills/` (13), `agents/` (4), `command/autoresearch.md`, `plugins/bstack.ts`. Clean up the temp dir afterward.

**Step 3: Commit**

```bash
git add scripts/install-opencode.sh
git commit -m "feat(opencode): add install script"
```

---

## Task 5: BATS tests

**Files:**
- Create: `tests/opencode_artifacts.bats`
- Modify: `tests/github_workflows.bats:169-176`

**Step 1: Write `tests/opencode_artifacts.bats`**

```bash
#!/usr/bin/env bats

load helpers/bats_helper

setup() {
    ensure_jq
}

OPENCODE_ROOT="${PROJECT_ROOT}/.opencode"

eligible_opencode_plugins() {
    jq -r '.plugins[].source' "${PROJECT_ROOT}/.claude-plugin/marketplace.json" | \
    sed 's|^\./plugins/||'
}

@test "opencode bundle includes all source skills" {
    local expected actual
    expected="$(
        while IFS= read -r plugin; do
            [ -n "$plugin" ] || continue
            for skill_dir in "${PROJECT_ROOT}/plugins/${plugin}"/skills/*/; do
                [ -d "$skill_dir" ] || continue
                basename "$skill_dir"
            done
        done < <(eligible_opencode_plugins) | sort
    )"
    actual="$(find "${OPENCODE_ROOT}/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)"

    [ "$actual" = "$expected" ]
}

@test "opencode bundle copies skill subdirectories verbatim" {
    local expected_files actual_files
    expected_files="$(
        find "${PROJECT_ROOT}/plugins/me/skills/create-pr" -type f | \
        sed -E "s|^${PROJECT_ROOT}/plugins/me/skills/create-pr/||" | sort
    )"
    actual_files="$(
        find "${OPENCODE_ROOT}/skills/create-pr" -type f | \
        sed -E "s|^${OPENCODE_ROOT}/skills/create-pr/||" | sort
    )"

    [ "$actual_files" = "$expected_files" ]
}

@test "opencode agents drop model and set subagent mode" {
    local expected_count
    expected_count="$(find "${PROJECT_ROOT}/plugins/me/agents" -name '*.md' | wc -l | tr -d ' ')"
    [ "$(find "${OPENCODE_ROOT}/agents" -name '*.md' | wc -l | tr -d ' ')" -eq "$expected_count" ]

    for agent in "${OPENCODE_ROOT}"/agents/*.md; do
        [ -f "$agent" ] || continue
        grep -q '^mode: subagent$' "$agent"
        run grep -qE '^model:' "$agent"
        [ "$status" -eq 1 ]
    done
}

@test "opencode command strips claude-only frontmatter" {
    assert_file_exists "${OPENCODE_ROOT}/command/autoresearch.md"
    grep -q '^description:' "${OPENCODE_ROOT}/command/autoresearch.md"
    run grep -qE '^(argument-hint|allowed-tools):' "${OPENCODE_ROOT}/command/autoresearch.md"
    [ "$status" -eq 1 ]
}

@test "opencode plugin ships commit guard and env injection" {
    assert_file_exists "${OPENCODE_ROOT}/plugins/bstack.ts"
    grep -q 'tool.execute.before' "${OPENCODE_ROOT}/plugins/bstack.ts"
    grep -q 'shell.env' "${OPENCODE_ROOT}/plugins/bstack.ts"
    grep -q 'CLAUDE_PLUGIN_ROOT' "${OPENCODE_ROOT}/plugins/bstack.ts"
}

@test "opencode drift check covers the whole bundle" {
    local check_script="${PROJECT_ROOT}/scripts/check-opencode-artifacts.sh"
    grep -q -- '-- .opencode' "$check_script"
    grep -q 'git ls-files --others --exclude-standard' "$check_script"
    run grep -q 'plugins/me/.opencode' "$check_script"
    [ "$status" -eq 1 ]
}
```

**Step 2: Update the sync-step test**

In `tests/github_workflows.bats`, inside `@test "Marketplace sync workflow calls sync script"`, add a third assertion after the existing two (`:175`):

```bash
    [[ "$sync_command" == *"bash scripts/sync-opencode-artifacts.sh"* ]]
```

**Step 3: Run the new tests**

Run: `bats tests/opencode_artifacts.bats tests/github_workflows.bats`
Expected: all pass.

**Step 4: Commit**

```bash
git add tests/opencode_artifacts.bats tests/github_workflows.bats
git commit -m "test(opencode): cover opencode artifact generation"
```

---

## Task 6: Release wiring (.releaserc.js)

**Files:**
- Modify: `.releaserc.js`

**Step 1: Sync opencode artifacts in `prepare`**

Inside `updatePluginJsons().prepare`, directly after the codex sync block (`const syncScript ... if (existsSync(syncScript)) { execSync(...) }`), add:

```js
      const opencodeSyncScript = resolve(process.cwd(), 'scripts/sync-opencode-artifacts.sh');
      if (existsSync(opencodeSyncScript)) {
        execSync(`bash ${opencodeSyncScript}`, { stdio: 'inherit' });
      }
```

**Step 2: Add opencode assets to the git commit**

After the `codexMarketplaceAsset` definition, add:

```js
const opencodeAssets = ['.opencode/**'];
```

In the `@semantic-release/git` plugin config, change the `assets` array to include `...opencodeAssets`:

```js
      assets: [
        ...pluginAssets,
        '.claude-plugin/marketplace.json',
        ...codexPluginAssets,
        ...codexMarketplaceAsset,
        ...opencodeAssets,
      ],
```

**Step 3: Verify JS loads**

Run: `node --check .releaserc.js`
Expected: exit 0.

**Step 4: Commit**

```bash
git add .releaserc.js
git commit -m "chore(opencode): sync and commit opencode artifacts on release"
```

---

## Task 7: CI/release workflows

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `.github/workflows/sync-marketplace.yml`

**Step 1: ci.yml**

After the `Install yq` step, add:

```yaml
      - name: Sync OpenCode artifacts
        run: bash scripts/sync-opencode-artifacts.sh
```

After the `Check Codex artifact drift` step, add:

```yaml
      - name: Check OpenCode artifact drift
        id: check_opencode_drift
        shell: bash
        run: bash scripts/check-opencode-artifacts.sh
```

Update the status-report condition so it also requires `check_opencode_drift` success:

```yaml
          script: |
            const state = '${{ steps.run_tests.outcome }}' === 'success' && '${{ steps.check_drift.outcome }}' === 'success' && '${{ steps.check_opencode_drift.outcome }}' === 'success'
              ? 'success'
              : 'failure';
```

**Step 2: release.yml**

After the `Install yq` step, add the same "Sync OpenCode artifacts" step as in ci.yml. After the `Check Codex artifact drift` step, add the same "Check OpenCode artifact drift" step.

**Step 3: sync-marketplace.yml**

In the `Sync marketplace artifacts` step, append:

```bash
          bash scripts/sync-opencode-artifacts.sh
```

In the `Check for changes` step, extend the diff and untracked lists to include `.opencode`:

```yaml
          untracked_artifacts="$(
            git ls-files --others --exclude-standard -- \
              .agents/plugins/marketplace.json \
              'plugins/*/.codex-plugin/plugin.json' \
              .opencode
          )"

          if git diff --quiet -- \
            .claude-plugin/marketplace.json \
            .agents/plugins/marketplace.json \
            'plugins/*/.codex-plugin/plugin.json' \
            .opencode && \
            [ -z "${untracked_artifacts}" ]; then
```

In the `Commit changes` step, add `.opencode` to `git add`:

```yaml
          git add \
            .claude-plugin/marketplace.json \
            .agents/plugins/marketplace.json \
            'plugins/*/.codex-plugin/plugin.json' \
            .opencode
```

**Step 4: Validate YAML**

Run: `pre-commit run check-yaml --all-files` (or `python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/ci.yml','.github/workflows/release.yml','.github/workflows/sync-marketplace.yml']]"`)
Expected: valid.

**Step 5: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/release.yml .github/workflows/sync-marketplace.yml
git commit -m "ci(opencode): sync and verify opencode artifacts"
```

---

## Task 8: Docs

**Files:**
- Modify: `README.md`
- Modify: `CLAUDE.md`

**Step 1: README OpenCode section**

After the `## Codex 호환성` section, add:

```markdown
## OpenCode 호환성

This repository generates OpenCode artifacts from the same Claude Code source of truth.

- Source of truth: `.claude-plugin/marketplace.json`, `plugins/*/.claude-plugin/plugin.json`
- Generated artifacts: `.opencode/` (skills, agents, command, `plugins/bstack.ts`)
- Do not edit generated `.opencode/` files directly; regenerate with `bun run sync:opencode`

```bash
bun run sync:opencode
bun run install:opencode
```

`install:opencode` symlinks the artifacts into `~/.config/opencode/` (skills, agents, command, and the `bstack.ts` commit-guard plugin). Restart opencode after installing. The `bstack.ts` plugin blocks dangerous git commands (`--no-verify`, hook bypasses) and injects `CLAUDE_PLUGIN_ROOT` so skill scripts resolve. Notes:

- `setup-worktree` / `agent-status` Claude Code hooks have no OpenCode equivalent.
- Skill names must be globally unique in OpenCode; on collision, resolve via opencode config permissions.
- Agents inherit the OpenCode default model.

Verify generated artifacts are in sync with `bun run check:opencode`.
```

**Step 2: CLAUDE.md artifact rule**

In `CLAUDE.md`, under `### Working In This Directory`, add:

```markdown
- Generated OpenCode artifacts live in `.opencode/`; regenerate with `bun run sync:opencode` (never edit them directly)
```

**Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: document opencode support"
```

---

## Task 9: Full verification

**Files:** none (verification only)

**Step 1: Regenerate from scratch**

Run: `rm -rf .opencode && bun run sync:opencode && bun run check:opencode`
Expected: `.opencode/` regenerated, check exits 0.

**Step 2: Run the full test suite**

Run: `bun run test`
Expected: all BATS suites pass.

**Step 3: Run pre-commit**

Run: `pre-commit run --all-files`
Expected: all hooks pass. If markdownlint flags generated `.opencode/**` files, run `bun run sync:opencode` after fixing sources rather than editing generated files.

**Step 4: Manual opencode smoke test**

Run: `OPENCODE_CONFIG_DIR="$(mktemp -d)" bash scripts/install-opencode.sh`, then confirm the temp dir has the 13 skill symlinks, 4 agent symlinks, `command/autoresearch.md`, and `plugins/bstack.ts`. Clean up the temp dir.

**Step 5: Confirm clean git state**

Run: `git status --porcelain`
Expected: only the design doc and implementation plan committed as untracked-to-be-reviewed; no generated drift.
