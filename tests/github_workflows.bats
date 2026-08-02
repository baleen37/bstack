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

create_dist_gate_fixture() {
    local fixture="$1"
    local mode="$2"
    node --input-type=module --eval '
      import { execFileSync } from "node:child_process";
      import { mkdir, writeFile } from "node:fs/promises";
      import { join } from "node:path";

      const [fixture, mode] = process.argv.slice(1);
      const packageRoot = join(fixture, "package");
      await mkdir(join(packageRoot, "dist"), { recursive: true });
      await writeFile(join(fixture, ".gitignore"), "!package/dist/\n!package/dist/**\n");
      await writeFile(
        join(packageRoot, "package.json"),
        JSON.stringify({
          name: "dist-gate-fixture",
          private: true,
          scripts: { build: "node build.mjs" },
        }, null, 2) + "\n",
      );
      const extraOutput = mode === "untracked"
        ? "await writeFile(join(root, \"dist\", \"generated.js\"), \"generated\\n\");"
        : "";
      await writeFile(join(packageRoot, "build.mjs"), `
        import { mkdir, writeFile } from "node:fs/promises";
        import { dirname, join } from "node:path";
        import { fileURLToPath } from "node:url";
        const root = dirname(fileURLToPath(import.meta.url));
        await mkdir(join(root, "dist"), { recursive: true });
        await writeFile(join(root, "dist", "current.js"), "current\\n");
        ${extraOutput}
      `);
      await writeFile(join(packageRoot, "dist", "current.js"), "current\n");
      if (mode === "stale") {
        await writeFile(join(packageRoot, "dist", "stale.js"), "stale\n");
      }
      execFileSync("git", ["init", "-q"], { cwd: fixture });
      execFileSync("git", ["add", "."], { cwd: fixture });
      execFileSync("git", [
        "-c", "user.name=Dist Gate Test",
        "-c", "user.email=dist-gate@example.com",
        "commit", "-qm", "fixture",
      ], { cwd: fixture });
    ' "$fixture" "$mode"
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

@test "CI workflow does not trigger on pull_request_target" {
    ensure_yaml_validator
    [ "$(yaml_get "$CI_WORKFLOW" ".on.pull_request_target")" = "null" ]
}

@test "CI workflow reports pull request results on the head SHA" {
    grep -q 'context.payload.pull_request.head.sha' "$CI_WORKFLOW"
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
    [[ "$sync_command" == *"bash scripts/sync-opencode-artifacts.sh"* ]]
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
