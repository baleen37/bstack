#!/usr/bin/env bash
set -euo pipefail

runtime="${AR_RUNTIME:-}"
max_iterations="${AR_MAX_ITERATIONS:-1}"
timeout_seconds="${AR_TIMEOUT:-0}"

die() {
  printf 'autoresearch loop: %s\n' "$*" >&2
  exit 2
}

[[ -f .autoresearch/autoresearch.md ]] || die 'missing .autoresearch/autoresearch.md'
[[ -f .autoresearch/run.sh ]] || die 'missing .autoresearch/run.sh'
[[ -f .autoresearch/results.jsonl ]] || die 'missing .autoresearch/results.jsonl; run the baseline first'
[[ "$max_iterations" =~ ^[0-9]+$ ]] || die 'AR_MAX_ITERATIONS must be a non-negative integer'
[[ "$timeout_seconds" =~ ^[0-9]+$ ]] || die 'AR_TIMEOUT must be a non-negative integer'

run_agent() {
  local prompt='Read .autoresearch/autoresearch.md and .autoresearch/results.jsonl. Perform exactly one autoresearch iteration: run the benchmark, keep or revert the scoped change, append one valid JSONL result, then stop.'

  case "$runtime" in
    codex) codex exec -C "$PWD" "$prompt" ;;
    claude) claude -p "$prompt" ;;
    *) die 'AR_RUNTIME must be codex or claude' ;;
  esac
}

run_agent_with_timeout() {
  if [[ "$timeout_seconds" -eq 0 ]]; then
    run_agent
    return
  fi

  run_agent &
  local agent_pid=$!
  (
    sleep "$timeout_seconds"
    kill "$agent_pid" 2>/dev/null || true
  ) &
  local killer_pid=$!
  local status=0
  set +e
  wait "$agent_pid"
  status=$?
  set -e
  kill "$killer_pid" 2>/dev/null || true
  wait "$killer_pid" 2>/dev/null || true
  return "$status"
}

iteration=0
while [[ "$max_iterations" -eq 0 || "$iteration" -lt "$max_iterations" ]]; do
  iteration=$((iteration + 1))
  printf 'autoresearch loop: iteration %d\n' "$iteration" >&2
  before_lines=$(wc -l < .autoresearch/results.jsonl | tr -d ' ')
  run_agent_with_timeout
  after_lines=$(wc -l < .autoresearch/results.jsonl | tr -d ' ')
  [[ "$after_lines" -eq $((before_lines + 1)) ]] || die 'iteration did not append exactly one results.jsonl row'
  jq -e . .autoresearch/results.jsonl >/dev/null || die 'results.jsonl contains invalid JSON'
done
