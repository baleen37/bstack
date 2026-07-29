#!/usr/bin/env bats
# Test: GitHub Actions workflows configuration

load helpers/bats_helper

# Path to workflow files
WORKFLOW_DIR="${PROJECT_ROOT}/.github/workflows"
CI_WORKFLOW="${WORKFLOW_DIR}/ci.yml"

# Helper: Parse YAML and extract value using yq
# Usage: yaml_get <file> <yaml_path>
# Example: yaml_get workflow.yml '.jobs.release.if'
yaml_get() {
    local file="$1"
    local path="$2"

    yq eval "$path" "$file" 2>/dev/null
}

# Helper: Check if workflow has specific trigger
workflow_has_trigger() {
    local workflow_file="$1"
    local trigger_type="$2"
    yaml_get "$workflow_file" ".on.${trigger_type}" &>/dev/null
}

# Helper: Check if job has 'if' condition
job_has_if_condition() {
    local workflow_file="$1"
    local job_name="$2"
    yaml_get "$workflow_file" ".jobs.${job_name}.if" &>/dev/null
}


@test "Workflow directory exists" {
    [ -d "$WORKFLOW_DIR" ]
}

@test "CI workflow file exists" {
    [ -f "$CI_WORKFLOW" ]
    [ -s "$CI_WORKFLOW" ]
}

@test "CI workflow has valid YAML syntax" {
    ensure_yaml_validator
    validate_yaml_file "$CI_WORKFLOW"
}

@test "CI workflow triggers on push to main" {
    ensure_yaml_validator
    workflow_has_trigger "$CI_WORKFLOW" "push"
}

@test "CI workflow triggers on pull_request" {
    ensure_yaml_validator
    workflow_has_trigger "$CI_WORKFLOW" "pull_request"
}

@test "CI workflow has only test job (no release job)" {
    ensure_yaml_validator
    # CI workflow should only have test job, release is handled by separate release.yml
    local jobs
    jobs=$(yaml_get "$CI_WORKFLOW" ".jobs | keys | .[]")

    [[ "$jobs" == "test" ]]

    # Verify release job doesn't exist (should return "null")
    local release_job
    release_job=$(yaml_get "$CI_WORKFLOW" ".jobs.release")
    [[ "$release_job" == "null" ]]
}

@test "CI workflow has read-only permissions" {
    ensure_yaml_validator
    local permissions
    permissions=$(yaml_get "$CI_WORKFLOW" ".permissions.contents")

    [[ "$permissions" == "read" ]]
}

@test "Release workflow exists" {
    [ -f "${WORKFLOW_DIR}/release.yml" ]
}

@test "Release workflow has valid YAML syntax" {
    ensure_yaml_validator
    validate_yaml_file "${WORKFLOW_DIR}/release.yml"
}

@test "Release workflow triggers on push to main" {
    ensure_yaml_validator
    workflow_has_trigger "${WORKFLOW_DIR}/release.yml" "push"
    local branches
    branches=$(yaml_get "${WORKFLOW_DIR}/release.yml" ".on.push.branches.[]")
    [[ "$branches" == "main" ]]
}

@test "Release workflow has required permissions" {
    ensure_yaml_validator
    local contents_perm
    contents_perm=$(yaml_get "${WORKFLOW_DIR}/release.yml" ".permissions.contents")
    [[ "$contents_perm" == "write" ]]
}

@test "Marketplace sync workflow exists" {
    [ -f "${WORKFLOW_DIR}/sync-marketplace.yml" ]
}

@test "Marketplace sync workflow has valid YAML syntax" {
    ensure_yaml_validator
    validate_yaml_file "${WORKFLOW_DIR}/sync-marketplace.yml"
}

@test "Marketplace sync workflow calls sync script" {
    ensure_yaml_validator
    local sync_command
    sync_command=$(yaml_get "${WORKFLOW_DIR}/sync-marketplace.yml" ".jobs.sync-marketplace.steps[] | select(.name == \"Sync marketplace artifacts\") | .run")

    [[ "$sync_command" == *"bash scripts/sync-marketplace-version.sh"* ]]
    [[ "$sync_command" == *"bash scripts/sync-codex-artifacts.sh"* ]]
}

@test "Release workflow has infinite loop prevention" {
    ensure_yaml_validator
    # Verify that the workflow prevents infinite loops from bot release commits
    local if_condition
    if_condition=$(yaml_get "${WORKFLOW_DIR}/release.yml" ".jobs.release.if")

    # Should check for bot actor and release commit message
    [[ "$if_condition" == *"[bot]"* ]]
    [[ "$if_condition" == *"chore(release):"* ]]
}

@test "Release workflow uses full git history" {
    ensure_yaml_validator
    # Verify that the workflow fetches full history for semantic-release
    local fetch_depth
    fetch_depth=$(yaml_get "${WORKFLOW_DIR}/release.yml" ".jobs.release.steps[] | select(.uses == \"actions/checkout@v4\") | .with.\"fetch-depth\"")

    [[ "$fetch_depth" == "0" ]]
}

@test "knowledge-base package is built and tested in CI without the real-model opt-in smoke" {
    ensure_yaml_validator
    local build_command
    local drift_command
    local test_command
    build_command=$(yaml_get "$CI_WORKFLOW" '.jobs.test.steps[] | select(.name == "Build knowledge-base package") | .run')
    drift_command=$(yaml_get "$CI_WORKFLOW" '.jobs.test.steps[] | select(.name == "Check knowledge-base build drift") | .run')
    test_command=$(yaml_get "$CI_WORKFLOW" '.jobs.test.steps[] | select(.name == "Test knowledge-base package") | .run')

    [[ "$build_command" == "bun run --cwd plugins/knowledge-base build" ]]
    [[ "$drift_command" == "git diff --exit-code -- plugins/knowledge-base/dist" ]]
    [[ "$test_command" == "bun run --cwd plugins/knowledge-base test" ]]
    ! grep -q 'KNOWLEDGE_BASE_REAL_MODEL=1' "$CI_WORKFLOW"
}

@test "release prepare synchronizes the nested knowledge-base package version" {
    run node --input-type=module --eval '
      import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
      import { tmpdir } from "node:os";
      import { join } from "node:path";
      import { pathToFileURL } from "node:url";

      const releaseConfig = process.argv[1];
      const fixture = await mkdtemp(join(tmpdir(), "knowledge-base-release-"));
      await mkdir(join(fixture, "plugins", "knowledge-base", ".claude-plugin"), { recursive: true });
      await mkdir(join(fixture, ".claude-plugin"), { recursive: true });
      await writeFile(join(fixture, "plugins", "knowledge-base", ".claude-plugin", "plugin.json"), "{\"name\":\"knowledge-base\",\"version\":\"0.0.0\"}\n");
      await writeFile(join(fixture, "plugins", "knowledge-base", "package.json"), "{\"name\":\"@baleen37/knowledge-base\",\"version\":\"0.0.0\"}\n");
      await writeFile(
        join(fixture, "plugins", "knowledge-base", "package-lock.json"),
        JSON.stringify({
          name: "@baleen37/knowledge-base",
          version: "0.0.0",
          lockfileVersion: 3,
          packages: {
            "": {
              name: "@baleen37/knowledge-base",
              version: "0.0.0",
            },
          },
        }, null, 2) + "\n",
      );
      await writeFile(join(fixture, ".claude-plugin", "marketplace.json"), "{\"plugins\":[{\"name\":\"knowledge-base\",\"version\":\"0.0.0\"}]}\n");
      const originalCwd = process.cwd();
      try {
        process.chdir(fixture);
        const { default: config } = await import(`${pathToFileURL(releaseConfig).href}?fixture=${Date.now()}`);
        const plugin = config.plugins.find((entry) => !Array.isArray(entry) && typeof entry.prepare === "function");
        await plugin.prepare({}, { nextRelease: { version: "99.0.0" } });
        const nested = JSON.parse(await readFile(join(fixture, "plugins", "knowledge-base", "package.json"), "utf8"));
        if (nested.version !== "99.0.0") throw new Error(`nested package version: ${nested.version}`);
        const lock = JSON.parse(await readFile(
          join(fixture, "plugins", "knowledge-base", "package-lock.json"),
          "utf8",
        ));
        if (lock.version !== "99.0.0") {
          throw new Error(`nested lock version: ${lock.version}`);
        }
        if (lock.packages[""].version !== "99.0.0") {
          throw new Error(`nested lock root version: ${lock.packages[""].version}`);
        }
      } finally {
        process.chdir(originalCwd);
        await rm(fixture, { recursive: true, force: true });
      }
    ' "${PROJECT_ROOT}/.releaserc.js"
    [ "$status" -eq 0 ]
}

@test "release git assets include the nested knowledge-base package" {
    run node --input-type=module --eval '
      const { default: config } = await import(process.argv[1]);
      const git = config.plugins.find((entry) => Array.isArray(entry) && entry[0] === "@semantic-release/git");
      if (!git[1].assets.includes("plugins/knowledge-base/package.json")) {
        throw new Error("nested knowledge-base package is not a release asset");
      }
      if (!git[1].assets.includes("plugins/knowledge-base/package-lock.json")) {
        throw new Error("nested knowledge-base package lock is not a release asset");
      }
    ' "file://${PROJECT_ROOT}/.releaserc.js"
    [ "$status" -eq 0 ]
}
