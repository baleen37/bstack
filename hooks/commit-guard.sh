#!/usr/bin/env bash
# Git Guard Hook: Git Command Validator
# Prevents --no-verify usage in git commands
# Reads JSON input from stdin for PreToolUse hooks

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Block a command with error message
block_command() {
    local error_msg="$1"
    local info_msg="${2:-}"

    echo -e "${RED}[ERROR]${NC} $error_msg" >&2
    if [ -n "$info_msg" ]; then
        echo -e "${GREEN}[INFO]${NC} $info_msg" >&2
    fi
    return 2
}

# Check if command matches a pattern
matches_pattern() {
    local command="$1"
    local pattern="$2"
    echo "$command" | grep -qE "$pattern"
}

# Check if text contains Co-Authored-By trailer
has_coauthored_by() {
    local text="$1"
    echo "$text" | grep -qE "Co-Authored-By:"
}

# Extract commit message from git commit command
# Handles -m "message" and -m message formats
# Also handles multiple -m flags (which are joined with newlines)
extract_commit_message() {
    local command="$1"
    local message=""

    # Extract all -m arguments (both -m "text" and -m text formats)
    # This regex captures the value after -m flag
    while [[ "$command" =~ (-m|--message)\s+([\"']?)([^\s\"']*)\2 ]]; do
        local captured="${BASH_REMATCH[3]}"
        # Replace the matched part to process next -m
        command="${command/"${BASH_REMATCH[0]}"/}"
        if [ -n "$message" ]; then
            message="$message
$captured"
        else
            message="$captured"
        fi
    done

    # Handle quoted strings with -m flag more carefully
    # Parse the command as if it were shell arguments
    local in_quotes=false
    local quote_char=""
    local current_arg=""
    local next_is_message=false

    for (( i=0; i<${#command}; i++ )); do
        local char="${command:$i:1}"

        if [ "$in_quotes" = true ]; then
            if [ "$char" = "$quote_char" ]; then
                in_quotes=false
                quote_char=""
            else
                current_arg="$current_arg$char"
            fi
        elif [ "$char" = "'" ] || [ "$char" = '"' ]; then
            in_quotes=true
            quote_char="$char"
        elif [ "$char" = " " ] || [ "$char" = $'\t' ]; then
            if [ "$next_is_message" = true ]; then
                if [ -n "$message" ]; then
                    message="$message
$current_arg"
                else
                    message="$current_arg"
                fi
                current_arg=""
                next_is_message=false
            elif [ "$current_arg" = "-m" ] || [ "$current_arg" = "--message" ]; then
                next_is_message=true
                current_arg=""
            else
                current_arg=""
            fi
        else
            current_arg="$current_arg$char"
        fi
    done

    # Handle last argument
    if [ "$next_is_message" = true ] && [ -n "$current_arg" ]; then
        if [ -n "$message" ]; then
            message="$message
$current_arg"
        else
            message="$current_arg"
        fi
    fi

    echo "$message"
}

validate_git_command() {
    local command="$1"

    # Quick exit: if not a git command, allow immediately
    if ! matches_pattern "$command" "^\s*(\S*=\S*\s+)*git\s+"; then
        return 0
    fi

    # Check for --no-verify in git commit commands
    if matches_pattern "$command" "git\s+commit.*--no-verify"; then
        block_command "--no-verify is not allowed in this repository" \
            "Please use 'git commit' without --no-verify. All commits must pass quality checks."
        return $?
    fi

    # Check for Co-Authored-By in git commit commands
    if matches_pattern "$command" "git\s+commit"; then
        local commit_message
        commit_message=$(extract_commit_message "$command")
        if [ -n "$commit_message" ] && has_coauthored_by "$commit_message"; then
            block_command "Co-Authored-By trailers are not allowed in commit messages" \
                "Please remove 'Co-Authored-By:' from your commit message."
            return $?
        fi
    fi

    # Check for other common bypass patterns
    if matches_pattern "$command" "git\s+.*skip.*hooks"; then
        block_command "Skipping hooks is not allowed"
        return $?
    fi

    if matches_pattern "$command" "git\s+.*--no-.*hook"; then
        block_command "Hook bypass is not allowed"
        return $?
    fi

    # Check for environment variable bypasses
    if matches_pattern "$command" "HUSKY=0.*git"; then
        block_command "HUSKY=0 bypass is not allowed"
        return $?
    fi

    if matches_pattern "$command" "SKIP_HOOKS=.*git"; then
        block_command "SKIP_HOOKS bypass is not allowed"
        return $?
    fi

    # Check for dangerous git commands that can bypass hooks
    if matches_pattern "$command" "git\s+update-ref"; then
        block_command "git update-ref is not allowed in this repository" \
            "This command can bypass commit hooks."
        return $?
    fi

    if matches_pattern "$command" "git\s+filter-branch"; then
        block_command "git filter-branch is not allowed in this repository" \
            "This command can rewrite history and bypass hooks."
        return $?
    fi

    # Check for hooksPath modification (security risk)
    if matches_pattern "$command" "git\s+config.*core\.hooksPath"; then
        block_command "Modifying core.hooksPath is not allowed in this repository" \
            "This can disable commit hooks."
        return $?
    fi

    return 0
}

# Extract git command from JSON input
extract_command_from_json() {
    local json_input="$1"
    echo "$json_input" | jq -r '.command // empty'
}

# Main execution
if [ $# -eq 0 ]; then
    # Read JSON from stdin (PreToolUse standard)
    json_input=$(cat)

    # Extract command from JSON
    command=$(extract_command_from_json "$json_input")

    # Validate the command if we got one
    if [ -n "$command" ]; then
        validate_git_command "$command"
        exit $?
    else
        # No command found, allow execution
        exit 0
    fi
else
    # Direct argument mode (fallback)
    command="$1"
    validate_git_command "$command"
    exit $?
fi
