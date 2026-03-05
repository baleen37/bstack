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

# Build the full command string for a given tool.
# Usage: build_command <tool> <tool_path> <model> <task_file> <result_file>
build_command() {
    local tool="$1" tool_path="$2" model="$3" task_file="$4" result_file="$5"
    local model_flag=""

    if [[ -n "$model" ]]; then
        model_flag=" --model ${model}"
    fi

    case "$tool" in
        claude)
            echo "${tool_path} -p \"\$(cat \"${task_file}\")\" --dangerously-skip-permissions${model_flag} > \"${result_file}\""
            ;;
        codex)
            echo "${tool_path} --full-auto -o \"${result_file}\"${model_flag} \"\$(cat \"${task_file}\")\""
            ;;
        gemini)
            echo "${tool_path} -p \"\$(cat \"${task_file}\")\" --yolo${model_flag} > \"${result_file}\""
            ;;
        *)
            echo "Unknown tool in build_command: ${tool}" >&2
            return 1
            ;;
    esac
}

# Dry-run mode: show built command and exit
if [[ "${DRY_RUN}" == true ]]; then
    echo "TOOL=${TOOL}"
    echo "TOOL_PATH=${TOOL_PATH}"
    echo "TASK=${TASK}"
    echo "MODEL=${MODEL}"
    echo "TIMEOUT=${TIMEOUT}"
    echo "CWD=${CWD}"
    CMD="$(build_command "$TOOL" "$TOOL_PATH" "$MODEL" "/tmp/task.txt" "/tmp/result.txt")"
    echo "CMD=${CMD}"
    exit 0
fi

# Set defaults for execution
TIMEOUT="${TIMEOUT:-300}"
CWD="${CWD:-$PWD}"

# Main execution via tmux
main() {
    # Check tmux availability
    if ! command -v tmux &>/dev/null; then
        echo "tmux is required but not found" >&2
        exit 1
    fi

    local id
    id="dispatch-$(date +%s)-$$"
    local task_file result_file
    task_file="$(mktemp "/tmp/${id}-task.XXXXXX")"
    result_file="$(mktemp "/tmp/${id}-result.XXXXXX")"
    local session="$id"

    # Write task to temp file
    echo "$TASK" > "$task_file"

    # Build command
    local cmd
    cmd="$(build_command "$TOOL" "$TOOL_PATH" "$MODEL" "$task_file" "$result_file")"

    # Cleanup trap
    cleanup() {
        tmux kill-session -t "$session" 2>/dev/null || true
        rm -f "$task_file" "$result_file"
    }
    trap cleanup EXIT

    # Create tmux session
    tmux new-session -d -s "$session" -x 220 -y 50 -c "$CWD"

    # Send command with literal mode
    tmux send-keys -t "$session" -l -- "$cmd && tmux wait-for -S $id"
    tmux send-keys -t "$session" Enter

    # Wait with timeout
    if ! timeout "$TIMEOUT" tmux wait-for "$id"; then
        echo "Timed out after ${TIMEOUT}s" >&2
        exit 124
    fi

    # Read and output result
    if [[ -s "$result_file" ]]; then
        cat "$result_file"
    fi
}

main
