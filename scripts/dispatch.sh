#!/usr/bin/env bash
set -euo pipefail

VALID_TOOLS="claude codex gemini"

# Untrusted path prefixes for binary resolution
UNTRUSTED_PATHS="/tmp /var/tmp /dev/shm"

# Resolve a binary name to an absolute path with safety checks.
# Rejects names with shell metacharacters, unresolvable binaries,
# and binaries in untrusted directories.
# Usage: resolve_binary <name>
# Prints the absolute path on success, exits with error on failure.
resolve_binary() {
    local name="$1"

    # Reject shell metacharacters
    if [[ "$name" =~ [\;\&\|\$\`\(\)\<\>\\] ]]; then
        echo "Binary name contains forbidden characters: ${name}" >&2
        return 1
    fi

    # Resolve to absolute path
    local resolved
    resolved="$(command -v "$name" 2>/dev/null)" || true
    if [[ -z "$resolved" ]]; then
        echo "Binary not found: ${name}" >&2
        return 1
    fi

    # Reject untrusted paths
    for prefix in $UNTRUSTED_PATHS; do
        if [[ "$resolved" == "${prefix}"/* ]]; then
            echo "Binary resolves to untrusted path: ${resolved}" >&2
            return 1
        fi
    done

    echo "$resolved"
}

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [OPTIONS] <tool> <task>

Dispatch a task to an AI CLI tool via tmux.

Tools: ${VALID_TOOLS}

Options:
  --model <model>      Model to use
  --timeout <seconds>  Timeout in seconds
  --cwd <directory>    Working directory
  --dry-run            Print parsed values and exit

Examples:
  $(basename "$0") claude "fix the login bug"
  $(basename "$0") --model sonnet --timeout 300 claude "refactor auth module"
EOF
    exit 1
}

# Defaults
MODEL=""
TIMEOUT=""
CWD=""
DRY_RUN=false

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)
            MODEL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --cwd)
            CWD="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --resolve-test)
            resolve_binary "$2"
            exit $?
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Require tool and task
if [[ $# -lt 1 ]]; then
    usage
fi

TOOL="$1"
shift

# Validate tool
# shellcheck disable=SC2076
if [[ ! " ${VALID_TOOLS} " =~ " ${TOOL} " ]]; then
    echo "Unknown tool: ${TOOL}" >&2
    echo "Valid tools: ${VALID_TOOLS}" >&2
    exit 1
fi

# Require task
if [[ $# -lt 1 ]] || [[ -z "$1" ]]; then
    echo "Task must not be empty" >&2
    exit 1
fi

TASK="$1"

# Resolve tool binary
TOOL_PATH="$(resolve_binary "$TOOL")"

# Dry-run mode: print parsed values and exit
if [[ "${DRY_RUN}" == true ]]; then
    echo "TOOL=${TOOL}"
    echo "TOOL_PATH=${TOOL_PATH}"
    echo "TASK=${TASK}"
    echo "MODEL=${MODEL}"
    echo "TIMEOUT=${TIMEOUT}"
    echo "CWD=${CWD}"
    exit 0
fi
