#!/usr/bin/env bash
# bats-core test helper for claude-plugins project
# This file provides project-level validation functions.
# Basic BATS helpers (setup, teardown, validate_json, etc.) are
# provided by @baleen/bats-helpers package.

# Project root directory
# BATS_TEST_DIRNAME is the directory containing the test file
# We need to find the project root from wherever the test is running
# shellcheck disable=SC2155
if [ -f "${BATS_TEST_DIRNAME}/helpers/bats_helper.bash" ]; then
    # Running from tests/ directory (most common case)
    # PROJECT_ROOT should be the parent of tests/
    export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
elif [ -f "${BATS_TEST_DIRNAME}/../../helpers/bats_helper.bash" ]; then
    # Running from tests/helpers/ directory (direct load)
    # PROJECT_ROOT should be two levels up
    export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
elif [ -f "${BATS_TEST_DIRNAME}/../../../tests/helpers/bats_helper.bash" ]; then
    # Running from plugins/{plugin}/tests/ directory
    # Need to go up 4 levels: tests/ -> plugin/ -> plugins/ -> project_root
    export PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
else
    # Fallback: use script location (resolve symlinks)
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    script_name="$(basename "${BASH_SOURCE[0]}")"
    # Resolve symlink if present (macOS compatible)
    if [ -L "${script_dir}/${script_name}" ]; then
        resolved="$(cd "${script_dir}" && \
                   cd "$(dirname "$(readlink "${script_dir}/${script_name}")")" && \
                   cd "../.." && pwd)"
        export PROJECT_ROOT="$resolved"
    elif [ -L "${script_dir}/${script_name}.bash" ]; then
        # Handle case where script_name doesn't have .bash but the link does
        resolved="$(cd "${script_dir}" && \
                   cd "$(dirname "$(readlink "${script_dir}/${script_name}.bash}")")" && \
                   cd "../.." && pwd)"
        export PROJECT_ROOT="$resolved"
    else
        export PROJECT_ROOT="$(cd "${script_dir}/../.." && pwd)"
    fi
fi

# Export common paths for use in test files
export WORKFLOW_DIR="${PROJECT_ROOT}/.github/workflows"

# Path to jq binary
JQ_BIN="${JQ_BIN:-jq}"

# Cached plugin list (populated once per test file)
_CACHED_PLUGIN_LIST=""

# Setup function - runs before each test
# shellcheck disable=SC2155
setup() {
    # Create temp directory for test-specific files
    export TEST_TEMP_DIR=$(mktemp -d -t claude-plugins-test.XXXXXX)

    # Initialize plugin list cache on first setup
    if [ -z "$_CACHED_PLUGIN_LIST" ]; then
        _CACHED_PLUGIN_LIST=$(find "$PROJECT_ROOT/plugins" -maxdepth 1 -type d ! -name "plugins" 2>/dev/null)
    fi
}

# Teardown function - runs after each test
teardown() {
    # Clean up temp directory
    if [ -n "${TEST_TEMP_DIR:-}" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Helper: Check if jq is available
ensure_jq() {
    if ! command -v "$JQ_BIN" &> /dev/null; then
        skip "jq not available"
    fi
}

# Helper: Validate JSON file
validate_json() {
    local file="$1"
    if ! $JQ_BIN empty "$file" 2>/dev/null; then
        echo "Error: Invalid JSON in $file" >&2
        $JQ_BIN empty "$file" >&2
        return 1
    fi
}

# Helper: Check if JSON field exists
json_has_field() {
    local file="$1"
    local field="$2"
    $JQ_BIN -e ".$field" "$file" &> /dev/null
}

# Helper: Get JSON field value
json_get() {
    local file="$1"
    local field="$2"
    $JQ_BIN -r ".$field" "$file"
}

# Helper: Check plugin name format (lowercase, hyphens, numbers only)
is_valid_plugin_name() {
    local name="$1"
    [[ "$name" =~ ^[a-z0-9-]+$ ]]
}

# Helper: Check if file has valid frontmatter delimiter
has_frontmatter_delimiter() {
    local file="$1"
    local content
    content=$(head -1 "$file")
    [[ "$content" == "---" ]]
}

# Helper: Check if file has frontmatter field
has_frontmatter_field() {
    local file="$1"
    local field="$2"
    grep -q "^${field}:" "$file"
}

# Helper: Count files matching pattern
count_files() {
    local pattern="$1"
    local base_dir="${2:-.}"
    find "$base_dir" -name "$pattern" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Helper: Check if JSON field is allowed in plugin.json
# Claude Code only supports: name, description, author, version, license, homepage, repository, keywords
# shellcheck disable=SC2076
json_field_is_allowed() {
    local field="$1"
    local allowed_fields="name description author version license homepage repository keywords lspServers"
    [[ " $allowed_fields " =~ " $field " ]]
}

# Helper: Check if author field is allowed (author.name, author.email)
# shellcheck disable=SC2076
json_author_field_is_allowed() {
    local field="$1"
    local allowed_author_fields="name email"
    [[ " $allowed_author_fields " =~ " $field " ]]
}

# Helper: Validate plugin.json has only allowed fields
validate_plugin_manifest_fields() {
    local file="$1"
    local all_fields
    all_fields=$($JQ_BIN -r 'keys_unsorted[]' "$file" 2>/dev/null)

    while IFS= read -r field; do
        if ! json_field_is_allowed "$field"; then
            echo "Error: Invalid field '$field' in $file"
            echo "Allowed fields: name, description, author, version, license, homepage, repository, keywords, lspServers"
            return 1
        fi
    done <<< "$all_fields"

    # Check nested author fields
    if $JQ_BIN -e '.author' "$file" &>/dev/null; then
        local author_fields
        author_fields=$($JQ_BIN -r '.author | keys_unsorted[]' "$file" 2>/dev/null)

        while IFS= read -r field; do
            if ! json_author_field_is_allowed "$field"; then
                echo "Error: Invalid author field 'author.$field' in $file"
                echo "Allowed author fields: name, email"
                return 1
            fi
        done <<< "$author_fields"
    fi

    return 0
}

# Helper: Iterate over all plugin manifest files
# Usage: for_each_plugin_manifest callback_function
for_each_plugin_manifest() {
    local callback="$1"
    local manifest_files
    manifest_files=$(find "$PROJECT_ROOT/plugins" -name "plugin.json" -type f 2>/dev/null)

    [ -n "$manifest_files" ] || return 1

    while IFS= read -r manifest_file; do
        $callback "$manifest_file"
    done <<< "$manifest_files"
}

# Helper: Check if JSON field has specific type
json_field_has_type() {
    local file="$1"
    local field="$2"
    local expected_type="$3"
    local actual_type
    actual_type=$($JQ_BIN -r ".$field | type" "$file" 2>/dev/null)
    [ "$actual_type" = "$expected_type" ]
}

# Helper: Validate semver format (major.minor.patch)
is_valid_semver() {
    local version="$1"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

# Helper: Assert with custom error message
# Usage: assert_eq <actual> <expected> <message>
assert_eq() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Values should be equal}"

    if [ "$actual" != "$expected" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Expected: $expected" >&2
        echo "  Actual:   $actual" >&2
        return 1
    fi
}

# Helper: Assert not empty with custom error message
# Usage: assert_not_empty <value> <message>
assert_not_empty() {
    local value="$1"
    local message="${2:-Value should not be empty}"

    if [ -z "$value" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Value is empty" >&2
        return 1
    fi
}

# Helper: Assert file exists with custom error message
# Usage: assert_file_exists <path> <message>
assert_file_exists() {
    local path="$1"
    local message="${2:-File should exist}"

    if [ ! -f "$path" ]; then
        echo "Assertion failed: $message" >&2
        echo "  File not found: $path" >&2
        return 1
    fi
}

# Helper: Assert directory exists with custom error message
# Usage: assert_dir_exists <path> <message>
assert_dir_exists() {
    local path="$1"
    local message="${2:-Directory should exist}"

    if [ ! -d "$path" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Directory not found: $path" >&2
        return 1
    fi
}

# Helper: Assert matches regex with custom error message
# Usage: assert_matches <value> <regex> <message>
assert_matches() {
    local value="$1"
    local regex="$2"
    local message="${3:-Value should match pattern}"

    if [[ ! "$value" =~ $regex ]]; then
        echo "Assertion failed: $message" >&2
        echo "  Value:    $value" >&2
        echo "  Pattern:  $regex" >&2
        return 1
    fi
}

# Helper: Assert success (exit code 0)
# Usage: assert_success
# shellcheck disable=SC2154
assert_success() {
    if [ "${status:-}" != 0 ]; then
        echo "Assertion failed: Command should succeed (exit code 0)" >&2
        echo "  Exit code: $status" >&2
        echo "  Output: $output" >&2
        return 1
    fi
}

# Helper: Assert failure (exit code not 0)
# Usage: assert_failure
# shellcheck disable=SC2154
assert_failure() {
    if [ "${status:-}" = 0 ]; then
        echo "Assertion failed: Command should fail (exit code not 0)" >&2
        echo "  Exit code: $status" >&2
        echo "  Output: $output" >&2
        return 1
    fi
}

# Helper: Assert output contains partial string
# Usage: assert_output --partial "substring"
# shellcheck disable=SC2155
assert_output() {
    local expected="$1"
    if [ "$expected" = "--partial" ]; then
        local substring="$2"
        if [[ ! "$output" == *"$substring"* ]]; then
            echo "Assertion failed: Output should contain '$substring'" >&2
            echo "  Output: $output" >&2
            return 1
        fi
    else
        if [ "$output" != "$expected" ]; then
            echo "Assertion failed: Output should equal '$expected'" >&2
            echo "  Output: $output" >&2
            return 1
        fi
    fi
}

# Performance optimization: Get cached plugin list
# Usage: get_all_plugins
get_all_plugins() {
    echo "$_CACHED_PLUGIN_LIST"
}

# Performance optimization: Get and cache plugin JSON data
# Usage: parse_plugin_json <plugin_path>
parse_plugin_json() {
    local plugin_path="$1"
    local json_file="${plugin_path}/.claude-plugin/plugin.json"

    # Parse the JSON (caching removed due to bash compatibility issues)
    if [ -f "$json_file" ]; then
        $JQ_BIN '.' "$json_file" 2>/dev/null
        return 0
    fi

    return 1
}

# Performance optimization: Clear plugin JSON cache (no-op now)
# Usage: clear_plugin_json_cache
clear_plugin_json_cache() {
    # No-op - caching removed for compatibility
    return 0
}

# Helper: Assert file does NOT exist
# Usage: assert_file_not_exists <path> <message>
assert_file_not_exists() {
    local path="$1"
    local message="${2:-File should not exist}"

    if [ -f "$path" ]; then
        echo "Assertion failed: $message" >&2
        echo "  File exists: $path" >&2
        return 1
    fi
}

# Helper: Assert directory does NOT exist
# Usage: assert_dir_not_exists <path> <message>
assert_dir_not_exists() {
    local path="$1"
    local message="${2:-Directory should not exist}"

    if [ -d "$path" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Directory exists: $path" >&2
        return 1
    fi
}

# Helper: Assert contains (array/string contains substring)
# Usage: assert_contains <haystack> <needle> <message>
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Value should contain substring}"

    if [[ ! "$haystack" == *"$needle"* ]]; then
        echo "Assertion failed: $message" >&2
        echo "  Haystack: $haystack" >&2
        echo "  Needle:   $needle" >&2
        return 1
    fi
}

# Helper: Assert does NOT contain
# Usage: assert_not_contains <haystack> <needle> <message>
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Value should not contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo "Assertion failed: $message" >&2
        echo "  Haystack: $haystack" >&2
        echo "  Found:    $needle" >&2
        return 1
    fi
}

# Helper: Assert greater than
# Usage: assert_gt <actual> <expected> <message>
assert_gt() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Value should be greater than expected}"

    if ! [[ "$actual" =~ ^[0-9]+$ ]] || ! [[ "$expected" =~ ^[0-9]+$ ]]; then
        echo "Assertion failed: $message" >&2
        echo "  Both values must be numeric" >&2
        echo "  Actual: $actual, Expected: $expected" >&2
        return 1
    fi

    if [ "$actual" -le "$expected" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Actual: $actual" >&2
        echo "  Expected to be greater than: $expected" >&2
        return 1
    fi
}

# Helper: Assert less than
# Usage: assert_lt <actual> <expected> <message>
assert_lt() {
    local actual="$1"
    local expected="$2"
    local message="${3:-Value should be less than expected}"

    if ! [[ "$actual" =~ ^[0-9]+$ ]] || ! [[ "$expected" =~ ^[0-9]+$ ]]; then
        echo "Assertion failed: $message" >&2
        echo "  Both values must be numeric" >&2
        echo "  Actual: $actual, Expected: $expected" >&2
        return 1
    fi

    if [ "$actual" -ge "$expected" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Actual: $actual" >&2
        echo "  Expected to be less than: $expected" >&2
        return 1
    fi
}

# Helper: Assert array contains element
# Usage: assert_array_contains <element> <array> <message>
# Array elements should be space-separated
assert_array_contains() {
    local element="$1"
    local array="$2"
    local message="${3:-Array should contain element}"

    for item in $array; do
        if [ "$item" = "$element" ]; then
            return 0
        fi
    done

    echo "Assertion failed: $message" >&2
    echo "  Element: $element" >&2
    echo "  Array:   $array" >&2
    return 1
}

# Helper: Assert valid YAML file
# Usage: assert_valid_yaml <path> <message>
assert_valid_yaml() {
    local path="$1"
    local message="${2:-File should be valid YAML}"

    if ! command -v yq &> /dev/null && ! command -v python3 &> /dev/null; then
        echo "Warning: Cannot validate YAML - yq or python3 not available" >&2
        return 0
    fi

    if command -v yq &> /dev/null; then
        if ! yq eval '.' "$path" > /dev/null 2>&1; then
            echo "Assertion failed: $message" >&2
            echo "  File: $path" >&2
            return 1
        fi
    elif command -v python3 &> /dev/null; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$path'))" 2>/dev/null; then
            echo "Assertion failed: $message" >&2
            echo "  File: $path" >&2
            return 1
        fi
    fi
}

# Helper: Get YAML field value (requires yq or python3)
# Usage: yaml_get <file> <field>
yaml_get() {
    local file="$1"
    local field="$2"

    if command -v yq &> /dev/null; then
        yq eval ".$field" "$file" 2>/dev/null
    elif command -v python3 &> /dev/null; then
        python3 -c "import yaml; print(yaml.safe_load(open('$file')).get('$field', ''))" 2>/dev/null
    else
        echo "Error: yq or python3 required for yaml_get" >&2
        return 1
    fi
}

# Helper: Ensure YAML validator is available
# Skips test if neither yq nor python3 is available
# Usage: ensure_yaml_validator
ensure_yaml_validator() {
    if ! command -v yq &> /dev/null && ! command -v python3 &> /dev/null; then
        skip "yq or python3 required for YAML validation"
    fi
}

# Helper: Validate YAML file syntax
# Returns 0 if valid, 1 if invalid
# Usage: validate_yaml_file <file>
validate_yaml_file() {
    local file="$1"

    if [ ! -f "$file" ]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    if command -v yq &> /dev/null; then
        yq eval '.' "$file" > /dev/null 2>&1
        return $?
    elif command -v python3 &> /dev/null; then
        python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null
        return $?
    else
        echo "Error: yq or python3 required for YAML validation" >&2
        return 1
    fi
}

# Helper: Assert file is executable
# Usage: assert_executable <path> <message>
assert_executable() {
    local path="$1"
    local message="${2:-File should be executable}"

    if [ ! -x "$path" ]; then
        echo "Assertion failed: $message" >&2
        echo "  File: $path" >&2
        return 1
    fi
}

# Helper: Count lines in file
# Usage: count_lines <file>
count_lines() {
    local file="$1"
    wc -l < "$file" 2>/dev/null | tr -d ' '
}

# Helper: Get file size in bytes
# Usage: file_size <file>
file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
}

# Helper: Assert file size is greater than
# Usage: assert_file_size_gt <file> <min_bytes> <message>
assert_file_size_gt() {
    local file="$1"
    local min_bytes="$2"
    local message="${3:-File should be larger than minimum size}"
    local size
    size=$(file_size "$file")

    if [ "$size" -le "$min_bytes" ]; then
        echo "Assertion failed: $message" >&2
        echo "  File: $file" >&2
        echo "  Size: $size bytes" >&2
        echo "  Minimum expected: $min_bytes bytes" >&2
        return 1
    fi
}

# Helper: Assert JSON field has expected value
# Usage: assert_json_field <file> <field> <expected_value> [message]
# Example: assert_json_field "$manifest" "name" "my-plugin"
assert_json_field() {
    local file="$1"
    local field="$2"
    local expected="$3"
    # shellcheck disable=SC2016
    local message="${4:-JSON field '$field' should have value '$expected'}"

    local actual
    actual=$($JQ_BIN -r ".$field" "$file" 2>/dev/null)

    if [ "$actual" != "$expected" ]; then
        echo "Assertion failed: $message" >&2
        echo "  File: $file" >&2
        echo "  Field: $field" >&2
        echo "  Expected: $expected" >&2
        echo "  Actual: $actual" >&2
        return 1
    fi
}

# Helper: Assert JSON field has expected type
# Usage: assert_json_field_type <file> <field> <expected_type> [message]
# Example: assert_json_field_type "$manifest" "keywords" "array"
assert_json_field_type() {
    local file="$1"
    local field="$2"
    local expected_type="$3"
    # shellcheck disable=SC2016
    local message="${4:-JSON field '$field' should be of type '$expected_type'}"

    if ! json_field_has_type "$file" "$field" "$expected_type"; then
        local actual_type
        actual_type=$($JQ_BIN -r ".$field | type" "$file" 2>/dev/null)
        echo "Assertion failed: $message" >&2
        echo "  File: $file" >&2
        echo "  Field: $field" >&2
        echo "  Expected type: $expected_type" >&2
        echo "  Actual type: $actual_type" >&2
        return 1
    fi
}

# Helper: Assert output contains substring (consistent wrapper)
# Usage: assert_output_contains <substring> [message]
# shellcheck disable=SC2154
assert_output_contains() {
    local substring="$1"
    # shellcheck disable=SC2016
    local message="${2:-Output should contain '$substring'}"

    if [[ ! "$output" == *"$substring"* ]]; then
        echo "Assertion failed: $message" >&2
        echo "  Expected substring: $substring" >&2
        echo "  Actual output: $output" >&2
        return 1
    fi
}

# Helper: Assert output matches regex pattern
# Usage: assert_output_matches <pattern> [message]
# shellcheck disable=SC2154
assert_output_matches() {
    local pattern="$1"
    # shellcheck disable=SC2016
    local message="${2:-Output should match pattern '$pattern'}"

    if [[ ! "$output" =~ $pattern ]]; then
        echo "Assertion failed: $message" >&2
        echo "  Expected pattern: $pattern" >&2
        echo "  Actual output: $output" >&2
        return 1
    fi
}

# Helper: Assert exit code with optional message check
# Usage: assert_exit_code <expected_code> [optional_substring]
# If optional_substring is provided, also checks that output contains it
# shellcheck disable=SC2154
assert_exit_code() {
    local expected="$1"
    local optional_substring="${2:-}"
    local message

    if [ "$expected" -eq 0 ]; then
        message="Command should succeed (exit code 0)"
    else
        message="Command should fail with exit code $expected"
    fi

    if [ "${status:-}" != "$expected" ]; then
        echo "Assertion failed: $message" >&2
        echo "  Expected exit code: $expected" >&2
        echo "  Actual exit code: $status" >&2
        echo "  Output: $output" >&2
        return 1
    fi

    # If substring provided, check output contains it
    if [ -n "$optional_substring" ]; then
        if [[ ! "$output" == *"$optional_substring"* ]]; then
            echo "Assertion failed: Output should contain '$optional_substring'" >&2
            echo "  Output: $output" >&2
            return 1
        fi
    fi
}
