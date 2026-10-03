#!/usr/bin/env bats
# Test: Codex actually loads the marketplace, plugins, skills, and hooks.
# Codex has no validate command, so this installs every plugin into a throwaway
# CODEX_HOME and asks `codex app-server` for the load errors it collected.

load helpers/bats_helper

MARKETPLACE_JSON="${PROJECT_ROOT}/.agents/plugins/marketplace.json"

# Send JSON-RPC requests to `codex app-server` over stdio and wait for every
# response. stdin must stay open until then: on EOF the server exits and drops
# pending requests.
codex_app_server() {
    local out="$1"
    shift
    local fifo="${BATS_FILE_TMPDIR}/app-server.in"
    # Notifications (no id) get no response.
    local expected
    expected=$(printf '%s\n' "$@" | jq -s '[.[] | select(.id)] | length')

    rm -f "$fifo"
    mkfifo "$fifo"
    codex app-server < "$fifo" > "$out" 2> "${out}.err" &
    local pid=$!
    # bats reserves fd 3, so let bash pick the writer fd.
    local writer
    exec {writer}> "$fifo"
    printf '%s\n' "$@" >&"$writer"

    local waited=0
    until [ "$(jq -s '[.[] | select(.id)] | length' "$out" 2>/dev/null)" = "$expected" ]; do
        if [ "$waited" -ge 600 ]; then
            exec {writer}>&-
            kill "$pid" 2>/dev/null || true
            echo "codex app-server timed out; stderr:" >&2
            cat "${out}.err" >&2
            return 1
        fi
        sleep 0.1
        waited=$((waited + 1))
    done
    exec {writer}>&-
    wait "$pid" || true
}

setup_file() {
    command -v codex >/dev/null 2>&1 || return 0

    export CODEX_HOME="${BATS_FILE_TMPDIR}/codex-home"
    mkdir -p "$CODEX_HOME"

    local marketplace plugin
    marketplace=$(jq -r '.name' "$MARKETPLACE_JSON")
    codex plugin marketplace add "$PROJECT_ROOT" --json >/dev/null
    for plugin in $(jq -r '.plugins[].name' "$MARKETPLACE_JSON"); do
        codex plugin add "${plugin}@${marketplace}" --json >/dev/null
    done

    local cwds
    cwds=$(jq -cn --arg cwd "$PROJECT_ROOT" '[$cwd]')
    codex_app_server "${BATS_FILE_TMPDIR}/app-server.out" \
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"bats","version":"0"}}}' \
        '{"jsonrpc":"2.0","method":"initialized"}' \
        '{"jsonrpc":"2.0","id":2,"method":"skills/list","params":{"cwds":'"$cwds"'}}' \
        '{"jsonrpc":"2.0","id":3,"method":"hooks/list","params":{"cwds":'"$cwds"'}}' \
        '{"jsonrpc":"2.0","id":4,"method":"plugin/list","params":{"cwds":'"$cwds"'}}'
}

setup() {
    command -v codex >/dev/null 2>&1 || skip "codex CLI not installed"
    ensure_jq
}

response() {
    jq -c --argjson id "$1" 'select(.id == $id)' "${BATS_FILE_TMPDIR}/app-server.out"
}

@test "codex loads the marketplace with every plugin" {
    local result
    result=$(response 4)
    [ "$(jq -c '.error' <<< "$result")" = "null" ] || { echo "$result"; return 1; }
    [ "$(jq -c '.result.marketplaceLoadErrors' <<< "$result")" = "[]" ] || { echo "$result"; return 1; }

    local marketplace expected actual
    marketplace=$(jq -r '.name' "$MARKETPLACE_JSON")
    expected=$(jq -c '[.plugins[].name] | sort' "$MARKETPLACE_JSON")
    actual=$(jq -c --arg m "$marketplace" '[.result.marketplaces[] | select(.name == $m) | .plugins[].name] | sort' <<< "$result")
    [ "$actual" = "$expected" ] || { echo "expected $expected, got $actual"; return 1; }
}

@test "codex reports no skill load errors" {
    local errors
    errors=$(response 2 | jq -c '[.result.data[].errors[]]')
    [ "$errors" = "[]" ] || { echo "$errors"; return 1; }
}

@test "codex loads every SKILL.md of every plugin" {
    local marketplace plugin expected actual failed=0
    marketplace=$(jq -r '.name' "$MARKETPLACE_JSON")
    for plugin in $(jq -r '.plugins[].name' "$MARKETPLACE_JSON"); do
        expected=$(find "${PROJECT_ROOT}/plugins/${plugin}/skills" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
        actual=$(response 2 | jq --arg id "${plugin}@${marketplace}" '[.result.data[].skills[] | select(.pluginId == $id)] | length')
        if [ "$actual" -ne "$expected" ]; then
            echo "${plugin}: codex loaded ${actual} of ${expected} skills"
            failed=1
        fi
    done
    [ "$failed" -eq 0 ]
}

@test "codex reports no hook warnings or errors" {
    local problems
    problems=$(response 3 | jq -c '[.result.data[] | .warnings[], .errors[]]')
    [ "$problems" = "[]" ] || { echo "$problems"; return 1; }
}
