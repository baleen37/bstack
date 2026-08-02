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
