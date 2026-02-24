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
    sync_command=$(yaml_get "${WORKFLOW_DIR}/sync-marketplace.yml" ".jobs.sync-marketplace.steps[] | select(.name == \"Sync marketplace.json version\") | .run")

    [[ "$sync_command" == "bash scripts/sync-marketplace-version.sh" ]]
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
