#!/usr/bin/env bats
# Consolidated plugin structure tests
# Tests for components that were previously in the me plugin

bats_require_minimum_version 1.5.0

load ../helpers/bats_helper

@test "core: create-pr scripts are executable" {
    [ -x "${PROJECT_ROOT}/plugins/core/skills/create-pr/scripts/preflight-check.sh" ]
    [ -x "${PROJECT_ROOT}/plugins/core/skills/create-pr/scripts/wait-for-merge.sh" ]
}
