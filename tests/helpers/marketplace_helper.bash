#!/usr/bin/env bash
# Marketplace helper for claude-plugins BATS tests
# Provides marketplace.json validation and query functions
#
# Usage:
#   load helpers/marketplace_helper  # in your BATS test file
#
# This file requires bats_helper.bash to be loaded first.

# Default path to marketplace.json
: "${MARKETPLACE_JSON:=${PROJECT_ROOT}/.claude-plugin/marketplace.json}"

###############################################################################
# MARKETPLACE.JSON QUERY FUNCTIONS
###############################################################################

# Get list of all plugins from marketplace.json
# Returns:
#   Newline-separated list of plugin source paths
# Usage:
#   local marketplace_plugins
#   marketplace_plugins=$(get_marketplace_plugins)
get_marketplace_plugins() {
    local marketplace_file="${1:-${MARKETPLACE_JSON}}"

    if [ ! -f "$marketplace_file" ]; then
        return 1
    fi

    $JQ_BIN -r '.plugins[].source' "$marketplace_file" 2>/dev/null
}

# Get the count of plugins listed in marketplace.json
# Returns:
#   Count of plugins in marketplace.json (outputs to stdout)
# Usage:
#   local count
#   count=$(marketplace_plugin_count)
marketplace_plugin_count() {
    local marketplace_file="${1:-${MARKETPLACE_JSON}}"

    if [ ! -f "$marketplace_file" ]; then
        echo "0"
        return 1
    fi

    $JQ_BIN -r '.plugins | length' "$marketplace_file" 2>/dev/null
}

###############################################################################
# MARKETPLACE.JSON VALIDATION FUNCTIONS
###############################################################################

# Check if a specific plugin exists in marketplace.json
# Args:
#   $1 - Plugin name to check
#   $2 - (Optional) Path to marketplace.json (defaults to MARKETPLACE_JSON)
# Returns:
#   0 if plugin exists in marketplace.json, 1 otherwise
# Usage:
#   if marketplace_plugin_exists "my-plugin"; then
#     echo "Plugin is listed"
#   fi
marketplace_plugin_exists() {
    local plugin_name="$1"
    local marketplace_file="${2:-${MARKETPLACE_JSON}}"

    if [ ! -f "$marketplace_file" ]; then
        return 1
    fi

    # Check if plugin name exists in plugins array
    $JQ_BIN -e --arg name "$plugin_name" \
        '.plugins[].source' "$marketplace_file" 2>/dev/null | \
        sed 's|^\./plugins/||' | \
        grep -q "^${plugin_name}$"
}

# Check if all plugins listed in marketplace.json exist in the filesystem
# Args:
#   $1 - (Optional) Path to marketplace.json (defaults to MARKETPLACE_JSON)
# Returns:
#   0 if all plugins exist, 1 otherwise (outputs missing plugins to stderr)
# Usage:
#   if ! marketplace_all_plugins_exist; then
#     echo "Some plugins are missing"
#   fi
marketplace_all_plugins_exist() {
    local marketplace_file="${1:-${MARKETPLACE_JSON}}"
    local sources
    local missing=0

    if [ ! -f "$marketplace_file" ]; then
        echo "Error: marketplace.json not found at $marketplace_file" >&2
        return 1
    fi

    sources=$(get_marketplace_plugins "$marketplace_file")

    while IFS= read -r source; do
        [ -z "$source" ] && continue

        # Resolve source path: "./" maps to PROJECT_ROOT
        local full_path
        if [ "$source" = "./" ] || [ "$source" = "." ]; then
            full_path="${PROJECT_ROOT}"
        else
            full_path="${PROJECT_ROOT}/${source}"
        fi

        if [ ! -d "$full_path" ]; then
            echo "Error: Plugin source '$source' does not exist at $full_path" >&2
            ((missing++))
        fi

        if [ ! -f "${full_path}/.claude-plugin/plugin.json" ]; then
            echo "Error: Plugin source '$source' missing plugin.json" >&2
            ((missing++))
        fi
    done <<< "$sources"

    return $missing
}

# Check if all plugins under plugins/ directory are listed in marketplace.json
# Args:
#   $1 - (Optional) Path to marketplace.json (defaults to MARKETPLACE_JSON)
# Returns:
#   0 if all plugins are listed, non-zero otherwise (outputs missing plugins to stderr)
# Usage:
#   if ! marketplace_all_plugins_listed; then
#     echo "Some plugins not listed"
#   fi
marketplace_all_plugins_listed() {
    local marketplace_file="${1:-${MARKETPLACE_JSON}}"

    if [ ! -f "$marketplace_file" ]; then
        echo "Error: marketplace.json not found at $marketplace_file" >&2
        return 1
    fi

    # Get all plugin directories under plugins/
    local expected_plugins
    expected_plugins=$(find "${PROJECT_ROOT}/plugins" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | sort)

    local missing=0
    while IFS= read -r plugin_name; do
        [ -z "$plugin_name" ] && continue
        local source="./plugins/${plugin_name}"
        local found
        found=$($JQ_BIN -r --arg src "$source" '.plugins[] | select(.source == $src) | .source' "$marketplace_file" 2>/dev/null)
        if [ -z "$found" ]; then
            echo "Error: Plugin '${plugin_name}' (source '${source}') not listed in marketplace.json" >&2
            ((missing++))
        fi
    done <<< "$expected_plugins"

    return $missing
}
