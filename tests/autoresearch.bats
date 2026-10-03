#!/usr/bin/env bats

load helpers/bats_helper

@test "autoresearch has no always-on prompt hook" {
  [ ! -f "$PROJECT_ROOT/plugins/autoresearch/hooks/hooks.json" ]
  [ ! -f "$PROJECT_ROOT/plugins/autoresearch/hooks/autoresearch-context.sh" ]
}

@test "autoresearch controller runs bounded fresh-agent iterations" {
  local controller="$PROJECT_ROOT/plugins/autoresearch/skills/autoresearch/scripts/loop.sh"
  [ -x "$controller" ]

  local fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >> "$AR_TEST_LOG"' 'printf "%s\\n" "{\"status\":\"keep\"}" >> .autoresearch/results.jsonl' > "$fake_bin/codex"
  chmod +x "$fake_bin/codex"

  local workdir="$BATS_TEST_TMPDIR/work"
  mkdir -p "$workdir/.autoresearch"
  touch "$workdir/.autoresearch/autoresearch.md" "$workdir/.autoresearch/run.sh" "$workdir/.autoresearch/results.jsonl"
  local log="$BATS_TEST_TMPDIR/agent.log"
  run env PATH="$fake_bin:$PATH" AR_RUNTIME=codex AR_MAX_ITERATIONS=2 \
    AR_TEST_LOG="$log" AR_TEST_WORKDIR="$workdir" AR_CONTROLLER="$controller" \
    bash -c 'cd "$AR_TEST_WORKDIR" && bash "$AR_CONTROLLER"'
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$log" | tr -d ' ')" -eq 2 ]
}

@test "autoresearch controller rejects an unknown runtime" {
  local workdir="$BATS_TEST_TMPDIR/work"
  mkdir -p "$workdir/.autoresearch"
  touch "$workdir/.autoresearch/autoresearch.md" "$workdir/.autoresearch/run.sh" "$workdir/.autoresearch/results.jsonl"
  run env AR_RUNTIME=unknown AR_MAX_ITERATIONS=1 AR_TEST_WORKDIR="$workdir" \
    AR_CONTROLLER="$PROJECT_ROOT/plugins/autoresearch/skills/autoresearch/scripts/loop.sh" \
    bash -c 'cd "$AR_TEST_WORKDIR" && bash "$AR_CONTROLLER"'
  [ "$status" -ne 0 ]
}
