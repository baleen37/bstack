#!/usr/bin/env bash
# Test utilities for claude-plugins BATS tests
# Provides higher-level validation and iteration helpers that build on bats_helper.bash
#
# Usage:
#   load helpers/test_utils  # in your BATS test file
#
# This file requires bats_helper.bash to be loaded first.

# Ensure jq is available for JSON operations
# shellcheck disable=SC2155
ensure_test_utils_deps() {
    if ! command -v "$JQ_BIN" &> /dev/null; then
        echo "Error: jq is required for test_utils functions" >&2
        return 1
    fi
    return 0
}

###############################################################################
# PLUGIN DISCOVERY FUNCTIONS
###############################################################################

# Find all plugin directories in the project
# Returns newline-separated list of absolute paths to plugin directories
# Usage: local plugins; plugins=$(find_all_plugins)
find_all_plugins() {
    find "$PROJECT_ROOT/plugins" -mindepth 1 -maxdepth 1 -type d ! -name ".*" 2>/dev/null | sort
}

# Get the path to plugin.json for a given plugin
# Args:
#   $1 - Plugin directory path (absolute or relative to project root)
# Returns:
#   Absolute path to plugin.json, or empty string if not found
# Usage: local manifest; manifest=$(get_plugin_manifest "$plugin_dir")
get_plugin_manifest() {
    local plugin_dir="$1"
    local manifest_file

    # Convert to absolute path if relative
    if [[ ! "$plugin_dir" = /* ]]; then
        plugin_dir="${PROJECT_ROOT}/${plugin_dir}"
    fi

    # Try standard location: .claude-plugin/plugin.json
    manifest_file="${plugin_dir}/.claude-plugin/plugin.json"
    if [ -f "$manifest_file" ]; then
        echo "$manifest_file"
        return 0
    fi

    # Try legacy location: package.json
    manifest_file="${plugin_dir}/package.json"
    if [ -f "$manifest_file" ]; then
        echo "$manifest_file"
        return 0
    fi

    echo ""
    return 1
}

# Check if a directory is a valid plugin (has plugin.json)
# Args:
#   $1 - Directory path to check
# Returns:
#   0 if valid plugin, 1 otherwise
# Usage: if is_plugin_dir "$dir"; then ...; fi
is_plugin_dir() {
    local dir="$1"
    local manifest
    manifest=$(get_plugin_manifest "$dir")
    [ -n "$manifest" ] && [ -f "$manifest" ]
}

# Execute a callback function for each plugin directory
# Args:
#   $1 - Callback function name (receives plugin dir path as first arg)
# Usage:
#   count_plugins() {
#     local count=0
#     for_each_plugin_file increment_count
#     echo $count
#   }
#   increment_count() {
#     ((count++))
#   }
for_each_plugin_file() {
    local callback="$1"
    local plugin_dirs

    plugin_dirs=$(find_all_plugins)

    [ -n "$plugin_dirs" ] || return 1

    while IFS= read -r plugin_dir; do
        $callback "$plugin_dir"
    done <<< "$plugin_dirs"
}

# Get plugin name from plugin directory path
# Args:
#   $1 - Plugin directory path (absolute or relative)
# Returns:
#   Plugin name (basename of directory)
# Usage: local name; name=$(get_plugin_name "$plugin_dir")
get_plugin_name() {
    local plugin_dir="$1"
    basename "$plugin_dir"
}

###############################################################################
# VALIDATION WRAPPER FUNCTIONS
###############################################################################

# Comprehensive plugin validation
# Checks:
#   - plugin.json exists and is valid JSON
#   - Has required fields (name, version)
#   - Has only allowed fields
#   - Name is valid format
# Args:
#   $1 - Plugin directory path
# Returns:
#   0 if valid, 1 otherwise (outputs error messages to stderr)
# Usage: if ! assert_valid_plugin "$plugin_dir"; then echo "Invalid!"; fi
assert_valid_plugin() {
    local plugin_dir="$1"
    local manifest
    local plugin_name
    local errors=0

    manifest=$(get_plugin_manifest "$plugin_dir")

    if [ -z "$manifest" ]; then
        echo "Error: No plugin.json found in $plugin_dir" >&2
        return 1
    fi

    # Check JSON validity
    if ! validate_json "$manifest"; then
        echo "Error: Invalid JSON in $manifest" >&2
        ((errors++))
    fi

    # Check required field: name
    if ! json_has_field "$manifest" "name"; then
        echo "Error: Missing required field 'name' in $manifest" >&2
        ((errors++))
    else
        plugin_name=$(json_get "$manifest" "name")
        # Validate name format (lowercase, hyphens, numbers)
        if ! is_valid_plugin_name "$plugin_name"; then
            echo "Error: Invalid plugin name '$plugin_name' in $manifest" >&2
            echo "Plugin names must be lowercase with hyphens or numbers only" >&2
            ((errors++))
        fi
    fi

    # Check required field: version
    if ! json_has_field "$manifest" "version"; then
        echo "Error: Missing required field 'version' in $manifest" >&2
        ((errors++))
    else
        local version
        version=$(json_get "$manifest" "version")
        if ! is_valid_semver "$version"; then
            echo "Error: Invalid version '$version' in $manifest" >&2
            echo "Version must be in semver format (e.g., 1.0.0)" >&2
            ((errors++))
        fi
    fi

    # Check for allowed fields only
    if ! validate_plugin_manifest_fields "$manifest"; then
        ((errors++))
    fi

    return $errors
}

# Validate a skill file (SKILL.md)
# Checks:
#   - File exists and is readable
#   - Has valid frontmatter delimiter
#   - Has required frontmatter fields (name, description)
# Args:
#   $1 - Path to SKILL.md file
# Returns:
#   0 if valid, 1 otherwise (outputs error messages to stderr)
# Usage: if ! assert_valid_skill "$skill_file"; then echo "Invalid!"; fi
assert_valid_skill() {
    local skill_file="$1"

    if [ ! -f "$skill_file" ]; then
        echo "Error: Skill file not found: $skill_file" >&2
        return 1
    fi

    if ! has_frontmatter_delimiter "$skill_file"; then
        echo "Error: Missing frontmatter delimiter in $skill_file" >&2
        return 1
    fi

    if ! has_frontmatter_field "$skill_file" "name"; then
        echo "Error: Missing required frontmatter field 'name' in $skill_file" >&2
        return 1
    fi

    if ! has_frontmatter_field "$skill_file" "description"; then
        echo "Error: Missing required frontmatter field 'description' in $skill_file" >&2
        return 1
    fi

    return 0
}

# Validate marketplace.json file
# Checks:
#   - File exists and is valid JSON
#   - Has required fields (name, owner, plugins)
#   - Plugins array is not empty
#   - Each plugin entry has required fields (name, source)
# Args:
#   $1 - Path to marketplace.json (defaults to PROJECT_ROOT/.claude-plugin/marketplace.json)
# Returns:
#   0 if valid, 1 otherwise (outputs error messages to stderr)
# Usage: if ! assert_valid_marketplace_json; then echo "Invalid!"; fi
assert_valid_marketplace_json() {
    local marketplace_file="${1:-${PROJECT_ROOT}/.claude-plugin/marketplace.json}"
    local errors=0

    if [ ! -f "$marketplace_file" ]; then
        echo "Error: marketplace.json not found at $marketplace_file" >&2
        return 1
    fi

    # Check JSON validity
    if ! validate_json "$marketplace_file"; then
        echo "Error: Invalid JSON in $marketplace_file" >&2
        return 1
    fi

    # Check required fields
    if ! json_has_field "$marketplace_file" "name"; then
        echo "Error: Missing required field 'name' in $marketplace_file" >&2
        ((errors++))
    fi

    if ! json_has_field "$marketplace_file" "owner"; then
        echo "Error: Missing required field 'owner' in $marketplace_file" >&2
        ((errors++))
    fi

    if ! json_has_field "$marketplace_file" "plugins"; then
        echo "Error: Missing required field 'plugins' in $marketplace_file" >&2
        ((errors++))
    else
        # Check plugins array exists and is not empty
        local plugins_count
        plugins_count=$($JQ_BIN -r '.plugins | length' "$marketplace_file" 2>/dev/null)
        if [ -z "$plugins_count" ] || [ "$plugins_count" -lt 1 ]; then
            echo "Error: 'plugins' array must not be empty in $marketplace_file" >&2
            ((errors++))
        fi
    fi

    return $errors
}

###############################################################################
# FILE ITERATION HELPERS
###############################################################################

# Iterate over all plugin manifest files
# This is a reference to the existing function in bats_helper.bash
# Usage:
#   for_each_plugin_manifest validate_manifest
#   validate_manifest() {
#     local manifest="$1"
#     validate_json "$manifest"
#   }
# NOTE: This function is already defined in bats_helper.bash
# This is just documentation for consistency

# Iterate over all SKILL.md files in the project
# Args:
#   $1 - Callback function name (receives SKILL.md path as first arg)
# Usage:
#   for_each_skill_file validate_skill
#   validate_skill() {
#     local skill_file="$1"
#     has_frontmatter_delimiter "$skill_file"
#   }
for_each_skill_file() {
    local callback="$1"
    local skill_files

    skill_files=$(find "$PROJECT_ROOT" -name "SKILL.md" -type f 2>/dev/null | grep -v ".worktrees" | sort)

    [ -n "$skill_files" ] || return 1

    while IFS= read -r skill_file; do
        $callback "$skill_file"
    done <<< "$skill_files"
}

# Iterate over all command files (*.md in commands/ directories)
# Args:
#   $1 - Callback function name (receives command file path as first arg)
# Usage:
#   for_each_command_file validate_command
#   validate_command() {
#     local cmd_file="$1"
#     has_frontmatter_delimiter "$cmd_file"
#   }
for_each_command_file() {
    local callback="$1"
    local cmd_files

    cmd_files=$(find "$PROJECT_ROOT/plugins" -path "*/commands/*.md" -type f 2>/dev/null | grep -v CLAUDE.md | sort)

    [ -n "$cmd_files" ] || return 1

    while IFS= read -r cmd_file; do
        $callback "$cmd_file"
    done <<< "$cmd_files"
}

# Iterate over all agent files (*.md in agents/ directories)
# Args:
#   $1 - Callback function name (receives agent file path as first arg)
# Usage:
#   for_each_agent_file validate_agent
#   validate_agent() {
#     local agent_file="$1"
#     has_frontmatter_delimiter "$agent_file"
#   }
for_each_agent_file() {
    local callback="$1"
    local agent_files

    agent_files=$(find "$PROJECT_ROOT/plugins" -path "*/agents/*.md" -type f 2>/dev/null | grep -v CLAUDE.md | sort)

    [ -n "$agent_files" ] || return 1

    while IFS= read -r agent_file; do
        $callback "$agent_file"
    done <<< "$agent_files"
}

# Iterate over all hooks.json files
# Args:
#   $1 - Callback function name (receives hooks.json path as first arg)
# Usage:
#   for_each_hooks_file validate_hooks
#   validate_hooks() {
#     local hooks_file="$1"
#     validate_json "$hooks_file"
#   }
for_each_hooks_file() {
    local callback="$1"
    local hooks_files

    hooks_files=$(find "$PROJECT_ROOT/plugins" -name "hooks.json" -path "*/hooks/hooks.json" -type f 2>/dev/null | sort)

    [ -n "$hooks_files" ] || return 1

    while IFS= read -r hooks_file; do
        $callback "$hooks_file"
    done <<< "$hooks_files"
}

###############################################################################
# COLLECTION VALIDATION HELPERS
###############################################################################

# Validate all plugins in the project
# Returns:
#   0 if all valid, 1 otherwise (outputs summary of errors)
# Usage: if ! validate_all_plugins; then echo "Some plugins are invalid"; fi
validate_all_plugins() {
    local plugin_dirs
    local total=0
    local valid=0
    local invalid=0

    plugin_dirs=$(find_all_plugins)

    [ -n "$plugin_dirs" ] || return 0

    while IFS= read -r plugin_dir; do
        ((total++))
        if assert_valid_plugin "$plugin_dir" 2>&1; then
            ((valid++))
        else
            ((invalid++))
        fi
    done <<< "$plugin_dirs"

    if [ "$invalid" -gt 0 ]; then
        echo "Plugin validation: $valid/$total valid, $invalid invalid" >&2
        return 1
    fi

    echo "Plugin validation: all $total plugins valid" >&2
    return 0
}

# Validate all skill files in the project
# Returns:
#   0 if all valid, 1 otherwise (outputs summary of errors)
# Usage: if ! validate_all_skills; then echo "Some skills are invalid"; fi
validate_all_skills() {
    local total=0
    local valid=0
    local invalid=0

    # shellcheck disable=SC2329
    _count_skill() {
        local skill_file="$1"
        ((total++))
        if assert_valid_skill "$skill_file" 2>&1; then
            ((valid++))
        else
            ((invalid++))
        fi
    }

    for_each_skill_file _count_skill

    if [ "$invalid" -gt 0 ]; then
        echo "Skill validation: $valid/$total valid, $invalid invalid" >&2
        return 1
    fi

    echo "Skill validation: all $total skills valid" >&2
    return 0
}

# Validate all command files in the project
# Returns:
#   0 if all have valid frontmatter, 1 otherwise
# Usage: if ! validate_all_commands; then echo "Some commands are invalid"; fi
validate_all_commands() {
    local total=0
    local valid=0
    local invalid=0

    # shellcheck disable=SC2329
    _count_command() {
        local cmd_file="$1"
        ((total++))
        if has_frontmatter_delimiter "$cmd_file"; then
            ((valid++))
        else
            ((invalid++))
            echo "Error: Missing frontmatter delimiter in $cmd_file" >&2
        fi
    }

    for_each_command_file _count_command

    if [ "$invalid" -gt 0 ]; then
        echo "Command validation: $valid/$total valid, $invalid invalid" >&2
        return 1
    fi

    echo "Command validation: all $total commands valid" >&2
    return 0
}

# Get count of items matching a pattern
# This is a more powerful version of count_files that supports multiple patterns
# Args:
#   $1 - Base directory to search
#   $2 - Find arguments (e.g., "-name *.json -type f")
# Returns:
#   Count of matching files
# Usage:
#   local count
#   count=$(count_matches "$PROJECT_ROOT/plugins" "-name plugin.json -type f")
count_matches() {
    local base_dir="$1"
    local find_args="$2"
    find "$base_dir" $find_args 2>/dev/null | wc -l | tr -d ' '
}

###############################################################################
# MARKETPLACE.JSON VALIDATION HELPERS
###############################################################################

# Get list of all plugins from marketplace.json
# Returns:
#   Newline-separated list of plugin source paths
# Usage:
#   local marketplace_plugins
#   marketplace_plugins=$(get_marketplace_plugins)
get_marketplace_plugins() {
    local marketplace_file="${1:-${PROJECT_ROOT}/.claude-plugin/marketplace.json}"

    if [ ! -f "$marketplace_file" ]; then
        return 1
    fi

    $JQ_BIN -r '.plugins[].source' "$marketplace_file" 2>/dev/null
}

# Check if all plugins in marketplace.json exist in the filesystem
# Returns:
#   0 if all exist, 1 otherwise (outputs missing plugins to stderr)
# Usage:
#   if ! check_marketplace_plugins_exist; then
#     echo "Some plugins are missing"
#   fi
check_marketplace_plugins_exist() {
    local marketplace_file="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
    local sources
    local missing=0

    if [ ! -f "$marketplace_file" ]; then
        echo "Error: marketplace.json not found" >&2
        return 1
    fi

    sources=$(get_marketplace_plugins "$marketplace_file")

    while IFS= read -r source; do
        local full_path="${PROJECT_ROOT}/${source}"

        if [ ! -d "$full_path" ]; then
            echo "Error: Plugin source '$source' does not exist" >&2
            ((missing++))
        fi

        if [ ! -f "${full_path}/.claude-plugin/plugin.json" ]; then
            echo "Error: Plugin source '$source' missing plugin.json" >&2
            ((missing++))
        fi
    done <<< "$sources"

    return $missing
}

# Check if all plugins in plugins/ are listed in marketplace.json
# Returns:
#   0 if all listed, 1 otherwise (outputs missing plugins to stderr)
# Usage:
#   if ! check_all_plugins_in_marketplace; then
#     echo "Some plugins are not listed"
#   fi
check_all_plugins_in_marketplace() {
    local marketplace_file="${PROJECT_ROOT}/.claude-plugin/marketplace.json"
    local plugin_dirs
    local missing=0

    if [ ! -f "$marketplace_file" ]; then
        echo "Error: marketplace.json not found" >&2
        return 1
    fi

    # Get plugins from marketplace (extract just plugin name from source path)
    local marketplace_plugins
    marketplace_plugins=$($JQ_BIN -r '.plugins[].source' "$marketplace_file" 2>/dev/null | sed 's|^\./plugins/||')

    # Check each plugin directory
    plugin_dirs=$(find_all_plugins)

    while IFS= read -r plugin_dir; do
        local plugin_name
        plugin_name=$(basename "$plugin_dir")

        # Skip if no plugin.json
        if ! is_plugin_dir "$plugin_dir"; then
            continue
        fi

        # Check if plugin is in marketplace.json
        if ! echo "$marketplace_plugins" | grep -q "^${plugin_name}$"; then
            echo "Error: Plugin '$plugin_name' not listed in marketplace.json" >&2
            ((missing++))
        fi
    done <<< "$plugin_dirs"

    return $missing
}

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

# Get relative path from project root
# Args:
#   $1 - Absolute path
# Returns:
#   Relative path from PROJECT_ROOT
# Usage:
#   local rel_path
#   rel_path=$(get_relative_path "/path/to/project/plugins/foo")
get_relative_path() {
    local abs_path="$1"
    local rel_path="${abs_path#"${PROJECT_ROOT}"/}"

    if [ "$rel_path" = "$abs_path" ]; then
        # Path is not under PROJECT_ROOT
        echo "$abs_path"
    else
        echo "$rel_path"
    fi
}

# Check if a path is under worktrees directory
# Args:
#   $1 - Path to check
# Returns:
#   0 if under worktrees, 1 otherwise
# Usage:
#   if is_under_worktrees "$path"; then continue; fi
is_under_worktrees() {
    local path="$1"
    [[ "$path" = */.worktrees/* ]]
}

# Check if a path is under node_modules
# Args:
#   $1 - Path to check
# Returns:
#   0 if under node_modules, 1 otherwise
# Usage:
#   if is_under_node_modules "$path"; then continue; fi
is_under_node_modules() {
    local path="$1"
    [[ "$path" = */node_modules/* ]]
}

# Run a function with error handling
# Args:
#   $1 - Function to run
#   $@ - Arguments to pass to function
# Returns:
#   Exit code of the function, with error output captured
# Usage:
#   run_with_error_handling validate_json "$file"
run_with_error_handling() {
    local func="$1"
    shift

    local output
    local exit_code

    output=$($func "$@" 2>&1)
    exit_code=$?

    if [ $exit_code -ne 0 ]; then
        echo "$output" >&2
    fi

    return $exit_code
}

###############################################################################
# COMPREHENSIVE PLUGIN MANIFEST VALIDATION
###############################################################################

# Run comprehensive validation on a plugin manifest
# Performs all standard checks including:
#   - JSON validity
#   - Required fields (name, description, author)
#   - Allowed fields only
#   - Plugin name format
#   - Field values not empty
# Args:
#   $1 - Plugin directory path or manifest file path
#   $2 - (Optional) Output file for validation results (defaults to stderr)
# Returns:
#   0 if all validations pass, 1 otherwise
# Usage:
#   if validate_plugin_manifest_comprehensive "$plugin_dir"; then
#     echo "Valid plugin!"
#   fi
validate_plugin_manifest_comprehensive() {
    local plugin_path="$1"
    local output_file="${2:-/dev/stderr}"
    local manifest
    local errors=0

    # Get manifest file path
    if [ -f "$plugin_path" ]; then
        manifest="$plugin_path"
    else
        manifest=$(get_plugin_manifest "$plugin_path")
    fi

    if [ -z "$manifest" ] || [ ! -f "$manifest" ]; then
        echo "Error: Plugin manifest not found for $plugin_path" >> "$output_file"
        return 1
    fi

    # Check JSON validity
    if ! validate_json "$manifest"; then
        echo "Error: Invalid JSON in $manifest" >> "$output_file"
        ((errors++))
    fi

    # Check required fields
    local required_fields=("name" "description" "author")
    for field in "${required_fields[@]}"; do
        if ! json_has_field "$manifest" "$field"; then
            echo "Error: Missing required field '$field' in $manifest" >> "$output_file"
            ((errors++))
        fi
    done

    # Check plugin name format if name exists
    if json_has_field "$manifest" "name"; then
        local plugin_name
        plugin_name=$(json_get "$manifest" "name")
        if ! is_valid_plugin_name "$plugin_name"; then
            echo "Error: Invalid plugin name '$plugin_name' in $manifest" >> "$output_file"
            ((errors++))
        fi
    fi

    # Check for allowed fields only
    if ! validate_plugin_manifest_fields "$manifest"; then
        echo "Error: Invalid fields found in $manifest" >> "$output_file"
        ((errors++))
    fi

    # Check field values are not empty
    local fields_to_check=("name" "description" "author")
    for field in "${fields_to_check[@]}"; do
        if json_has_field "$manifest" "$field"; then
            local value
            value=$(json_get "$manifest" "$field")
            if [ -z "$value" ]; then
                echo "Error: Field '$field' is empty in $manifest" >> "$output_file"
                ((errors++))
            fi
        fi
    done

    return $errors
}

# Check all plugin manifests in the project
# Runs comprehensive validation on all plugins found
# Args:
#   $1 - (Optional) Output file for validation results (defaults to stderr)
# Returns:
#   0 if all plugins valid, 1 otherwise
# Usage:
#   if check_all_plugin_manifests; then
#     echo "All plugins are valid!"
#   fi
check_all_plugin_manifests() {
    local output_file="${1:-/dev/stderr}"
    local plugin_dirs
    local total=0
    local valid=0
    local invalid=0

    plugin_dirs=$(find_all_plugins)

    [ -n "$plugin_dirs" ] || return 0

    while IFS= read -r plugin_dir; do
        ((total++))
        local result_file="${TEST_TEMP_DIR}/validation_$$_$total.txt"

        if validate_plugin_manifest_comprehensive "$plugin_dir" "$result_file" 2>&1; then
            ((valid++))
            rm -f "$result_file"
        else
            ((invalid++))
            cat "$result_file" >> "$output_file"
            rm -f "$result_file"
        fi
    done <<< "$plugin_dirs"

    if [ "$invalid" -gt 0 ]; then
        echo "" >> "$output_file"
        echo "Plugin validation summary: $valid/$total valid, $invalid invalid" >> "$output_file"
        return 1
    fi

    echo "Plugin validation summary: all $total plugins valid" >> "$output_file"
    return 0
}

# Count valid plugins in the project
# Returns the count of plugins that pass validation
# Args:
#   None
# Returns:
#   Count of valid plugins (outputs to stdout)
# Usage:
#   local count
#   count=$(count_valid_plugins)
count_valid_plugins() {
    local plugin_dirs
    local count=0

    plugin_dirs=$(find_all_plugins)

    [ -n "$plugin_dirs" ] || { echo "0"; return 0; }

    while IFS= read -r plugin_dir; do
        local result_file="${TEST_TEMP_DIR}/count_validation_$$_$count.txt"

        if validate_plugin_manifest_comprehensive "$plugin_dir" "$result_file" 2>&1; then
            ((count++))
        fi
        rm -f "$result_file"
    done <<< "$plugin_dirs"

    echo "$count"
}

# Get list of invalid plugins in the project
# Returns newline-separated list of plugin names that fail validation
# Args:
#   None
# Returns:
#   List of invalid plugin names (outputs to stdout)
# Usage:
#   local invalid
#   invalid=$(get_invalid_plugins)
#   if [ -n "$invalid" ]; then
#     echo "Invalid plugins: $invalid"
#   fi
get_invalid_plugins() {
    local plugin_dirs
    local invalid_plugins=""

    plugin_dirs=$(find_all_plugins)

    [ -n "$plugin_dirs" ] || { echo ""; return 0; }

    while IFS= read -r plugin_dir; do
        local plugin_name
        plugin_name=$(get_plugin_name "$plugin_dir")
        local result_file="${TEST_TEMP_DIR}/invalid_check_$$_$RANDOM.txt"

        if ! validate_plugin_manifest_comprehensive "$plugin_dir" "$result_file" 2>&1; then
            if [ -n "$invalid_plugins" ]; then
                invalid_plugins="$invalid_plugins"$'\n'"$plugin_name"
            else
                invalid_plugins="$plugin_name"
            fi
        fi
        rm -f "$result_file"
    done <<< "$plugin_dirs"

    echo "$invalid_plugins"
}
