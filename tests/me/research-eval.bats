#!/usr/bin/env bats

load ../helpers/bats_helper

EVALUATE="${PROJECT_ROOT}/plugins/me/skills/research/scripts/evaluate.ts"
UNIT_TEST="${PROJECT_ROOT}/tests/me/research-evaluator.test.ts"

setup() {
  export TEST_TEMP_DIR
  TEST_TEMP_DIR=$(mktemp -d -t claude-plugins-test.XXXXXX)
  mkdir -p "$TEST_TEMP_DIR/bin"

  cat >"$TEST_TEMP_DIR/bin/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$TEST_TEMP_DIR/codex.args"
last_message=""
schema_path=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--output-schema" ]; then
    schema_path="$2"
    shift 2
    continue
  fi
  if [ "$1" = "--output-last-message" ]; then
    last_message="$2"
    shift 2
    continue
  fi
  shift
done
prompt=$(cat)
cp "$schema_path" "$TEST_TEMP_DIR/codex.schema.json"
if [[ "$prompt" == *ROUTE_ONLY* ]]; then
  printf '%s\n' '{"route":"direct","brief":"Read the supplied RFC section and answer the question.","answer":""}' >"$last_message"
  exit 0
fi
if [ "${RESEARCH_EVAL_FAKE_REJECT_TRANSPORT_SCHEMA:-}" = "1" ] && jq -e '.. | objects | keys[]? | select(. == "$schema" or . == "format" or . == "minLength")' "$schema_path" >/dev/null; then
  printf '%s\n' '{"type":"error","message":"invalid_json_schema: uri is not a valid format"}'
  printf '%s\n' '{"type":"turn.failed","error":{"message":"invalid_json_schema: uri is not a valid format"}}'
  exit 1
fi
if [ "${RESEARCH_EVAL_FAKE_JSONL_FAILURE:-}" = "1" ]; then
  printf '%s\n' '{"type":"error","message":"invalid_json_schema: uri is not a valid format"}'
  printf '%s\n' '{"type":"turn.failed","error":{"message":"invalid_json_schema: uri is not a valid format"}}'
  exit 1
fi
if [ "${RESEARCH_EVAL_FAKE_AUTH_UNAVAILABLE:-}" = "1" ]; then
  printf '%s\n' 'OAuth login required' >&2
  exit 1
fi
if [ "${RESEARCH_EVAL_FAKE_SKIP_OPEN:-}" != "1" ]; then
  printf '%s\n' '{"type":"item.completed","item":{"type":"mcp_tool_call","tool":"open","arguments":{"ref_id":"https://www.rfc-editor.org/rfc/rfc9110"}}}'
fi
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":90,"output_tokens":25}}'
printf '%s\n' '{"answerState":"supported","answerMarkdown":"GET, HEAD, OPTIONS, and TRACE are safe ([RFC 9110](https://www.rfc-editor.org/rfc/rfc9110)).","sources":[{"title":"RFC 9110","url":"https://www.rfc-editor.org/rfc/rfc9110","claim":"GET, HEAD, OPTIONS, and TRACE are safe"}],"uncertainty":""}' >"$last_message"
EOF

  cat >"$TEST_TEMP_DIR/bin/claude" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >>"$TEST_TEMP_DIR/claude.args"
if [[ "$*" == *ROUTE_ONLY* ]]; then
  printf '%s\n' '{"type":"result","result":"{\"route\":\"direct\",\"brief\":\"Read the supplied RFC section and answer the question.\",\"answer\":\"\"}"}'
  exit 0
fi
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"WebFetch","input":{"url":"https://www.rfc-editor.org/rfc/rfc9110"}}],"usage":{"input_tokens":90,"output_tokens":25}}}'
printf '%s\n' '{"type":"result","result":"{\"answerState\":\"supported\",\"answerMarkdown\":\"GET, HEAD, OPTIONS, and TRACE are safe ([RFC 9110](https://www.rfc-editor.org/rfc/rfc9110)).\",\"sources\":[{\"title\":\"RFC 9110\",\"url\":\"https://www.rfc-editor.org/rfc/rfc9110\",\"claim\":\"GET, HEAD, OPTIONS, and TRACE are safe\"}],\"uncertainty\":\"\"}"}'
EOF
  chmod +x "$TEST_TEMP_DIR/bin/codex" "$TEST_TEMP_DIR/bin/claude"
}

teardown() {
  rm -rf "$TEST_TEMP_DIR"
}

@test "research evaluator: pure TypeScript tests pass" {
  run bun test "$UNIT_TEST"
  [ "$status" -eq 0 ]
}

@test "research evaluator: validates scenarios and result schema" {
  run bun "$EVALUATE" --validate
  [ "$status" -eq 0 ]
  [[ "$output" == *"10 scenarios valid"* ]]
}

@test "research evaluator: rejects a missing runtime" {
  run bun "$EVALUATE" --variant baseline --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--runtime is required"* ]]
}

@test "research evaluator: runs Codex in an ephemeral read-only directory" {
  run env \
    RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" \
    bun "$EVALUATE" \
      --runtime codex \
      --variant baseline \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 0 ]
  grep -q -- "--ephemeral" "$TEST_TEMP_DIR/codex.args"
  grep -q -- "--ignore-user-config" "$TEST_TEMP_DIR/codex.args"
  grep -Fx -- "--sandbox" "$TEST_TEMP_DIR/codex.args"
  grep -Fx -- "read-only" "$TEST_TEMP_DIR/codex.args"
  jq -e '.runs[0].runtime == "codex"' \
    "$TEST_TEMP_DIR/out/summary.json"
}

@test "research evaluator: runs Claude without session persistence" {
  run env \
    RESEARCH_EVAL_CLAUDE_BIN="$TEST_TEMP_DIR/bin/claude" \
    bun "$EVALUATE" \
      --runtime claude \
      --variant candidate \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 0 ]
  grep -q -- "--safe-mode" "$TEST_TEMP_DIR/claude.args"
  grep -q -- "--no-session-persistence" "$TEST_TEMP_DIR/claude.args"
  grep -Fx -- "--output-format" "$TEST_TEMP_DIR/claude.args"
  grep -Fx -- "stream-json" "$TEST_TEMP_DIR/claude.args"
  jq -e '.runs[0].runtime == "claude"' \
    "$TEST_TEMP_DIR/out/summary.json"
}

@test "research evaluator: sanitizes the Codex transport schema" {
  run env \
    RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" \
    RESEARCH_EVAL_FAKE_REJECT_TRANSPORT_SCHEMA=1 \
    bun "$EVALUATE" \
      --runtime codex \
      --variant baseline \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 0 ]
  jq -e '
    ([.. | objects | keys[] | select(. == "$schema" or . == "format" or . == "minLength")] | length == 0)
    and (.properties | type == "object")
    and (.required == ["answerState", "answerMarkdown", "sources", "uncertainty"])
    and (.additionalProperties == false)
    and (.properties.answerState.enum == ["supported", "unavailable", "out_of_scope"])
    and (.properties.sources.items.properties.url.type == "string")
    and (.properties.sources.items.required == ["title", "url", "claim"])
    and (.properties.sources.items.additionalProperties == false)' \
    "$TEST_TEMP_DIR/codex.schema.json"
}

@test "research evaluator: preserves schema property names while sanitizing their schemas" {
  cat >"$TEST_TEMP_DIR/property-schema.ts" <<EOF
import { runStructured } from "${PROJECT_ROOT}/plugins/me/skills/research/scripts/runtime-adapters";

await runStructured({
  runtime: "codex",
  systemPrompt: "execution",
  userPrompt: "answer",
  schema: {
    type: "object",
    properties: {
      format: { type: "string", format: "uri" },
      minLength: { type: "string", minLength: 1 },
      "\$schema": { type: "string", "\$schema": "https://example.test/schema" },
    },
    required: ["format", "minLength", "\$schema"],
    additionalProperties: false,
  },
  workingDirectory: process.cwd(),
});
EOF
  run env RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" bun "$TEST_TEMP_DIR/property-schema.ts"
  [ "$status" -eq 0 ]
  jq -e '
    (.properties | has("format") and has("minLength") and has("$schema"))
    and (.required == ["format", "minLength", "$schema"])
    and (.properties.format.type == "string" and (.properties.format | has("format") | not))
    and (.properties.minLength.type == "string" and (.properties.minLength | has("minLength") | not))
    and (.properties["$schema"].type == "string" and (.properties["$schema"] | has("$schema") | not))' \
    "$TEST_TEMP_DIR/codex.schema.json"
}

@test "research evaluator: preserves Codex JSONL failures without stderr" {
  run env \
    RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" \
    RESEARCH_EVAL_FAKE_JSONL_FAILURE=1 \
    bun "$EVALUATE" \
      --runtime codex \
      --variant baseline \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 1 ]
  jq -e '
    .runs[0].process.failureDetail == "invalid_json_schema: uri is not a valid format"
    and .runs[0].answer.answerState == "unavailable"
    and .runs[0].answer.answerMarkdown == "invalid_json_schema: uri is not a valid format"' \
    "$TEST_TEMP_DIR/out/summary.json"
}

@test "research evaluator: rejects a different runtime in an existing output directory" {
  run env \
    RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" \
    bun "$EVALUATE" \
      --runtime codex \
      --variant baseline \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 0 ]
  run env \
    RESEARCH_EVAL_CLAUDE_BIN="$TEST_TEMP_DIR/bin/claude" \
    bun "$EVALUATE" \
      --runtime claude \
      --variant baseline \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 2 ]
  [[ "$output" == *"output directory has different runtime"* ]]
}

@test "research evaluator: preserves failure and exact instruction hashes" {
  export RESEARCH_EVAL_FAKE_SKIP_OPEN=1
  run env \
    RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" \
    bun "$EVALUATE" \
      --runtime codex \
      --variant baseline \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 1 ]
  jq -e \
    '.runs[0].status == "incomplete"
     and (.instructionHashes.skill | length == 64)
     and (.instructionHashes.researcher | length == 64)' \
    "$TEST_TEMP_DIR/out/summary.json"
}

@test "research evaluator: preserves authentication failures as incomplete" {
  run env \
    RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" \
    RESEARCH_EVAL_FAKE_AUTH_UNAVAILABLE=1 \
    bun "$EVALUATE" \
      --runtime codex \
      --variant baseline \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 1 ]
  jq -e \
    '.runs[0].status == "incomplete"
     and .runs[0].process.availability == "auth_unavailable"
     and (.runs[0].process.failureDetail | contains("OAuth login required"))' \
    "$TEST_TEMP_DIR/out/summary.json"
}
