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
prompt=""
system_prompt=""
print_mode=0
output_format=""
verbose=0
json_schema=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p)
      print_mode=1
      shift
      ;;
    --verbose)
      verbose=1
      shift
      ;;
    --safe-mode|--no-session-persistence)
      shift
      ;;
    --output-format)
      output_format="$2"
      shift 2
      ;;
    --json-schema)
      json_schema="$2"
      shift 2
      ;;
    --permission-mode)
      shift 2
      ;;
    --system-prompt)
      system_prompt="$2"
      shift 2
      ;;
    --tools)
      shift
      while [ "$#" -gt 0 ] && [[ "$1" != -* ]]; do
        shift
      done
      ;;
    -*)
      printf '%s\n' "unexpected option: $1" >&2
      exit 2
      ;;
    *)
      if [ -n "$prompt" ]; then
        printf '%s\n' "unexpected positional argument" >&2
        exit 2
      fi
      prompt="$1"
      shift
      ;;
  esac
done
if [ -z "$prompt" ]; then
  printf '%s\n' "Error: Input must be provided either through stdin or as a prompt argument when using --print" >&2
  exit 1
fi
if [ "$print_mode" = "1" ] && [ "$output_format" = "stream-json" ] && [ "$verbose" != "1" ]; then
  printf '%s\n' "Error: When using --print, --output-format=stream-json requires --verbose" >&2
  exit 1
fi
printf '%s\n' "$json_schema" >>"$TEST_TEMP_DIR/claude.schemas.jsonl"
if jq -e 'has("$schema")' <<<"$json_schema" >/dev/null; then
  printf '%s\n' 'Error: --json-schema is not a valid JSON Schema: no schema with key or ref "https://json-schema.org/draft/2020-12/schema"' >&2
  exit 1
fi
printf '%s\n' "prompt-present" >>"$TEST_TEMP_DIR/claude.parsed"
if [[ "$system_prompt" == *ROUTE_ONLY* ]]; then
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

@test "research evaluator: runs Claude verbosely without session persistence" {
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
  [ "$(grep -cFx -- "--verbose" "$TEST_TEMP_DIR/claude.args")" -eq 2 ]
  jq -e '.runs[0].runtime == "claude"' \
    "$TEST_TEMP_DIR/out/summary.json"
}

@test "research evaluator: passes both Claude prompts before variadic tools" {
  run env \
    RESEARCH_EVAL_CLAUDE_BIN="$TEST_TEMP_DIR/bin/claude" \
    bun "$EVALUATE" \
      --runtime claude \
      --variant candidate \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^prompt-present$' "$TEST_TEMP_DIR/claude.parsed")" -eq 2 ]
}

@test "research evaluator: removes only Claude transport schema dialect metadata" {
  run env \
    RESEARCH_EVAL_CLAUDE_BIN="$TEST_TEMP_DIR/bin/claude" \
    bun "$EVALUATE" \
      --runtime claude \
      --variant candidate \
      --scenario exact-rfc-safe-methods \
      --output-dir "$TEST_TEMP_DIR/out"
  [ "$status" -eq 0 ]
  jq -s -e '
    length == 2
    and all(.[]; has("$schema") | not)
    and .[0].required == ["route", "brief", "answer"]
    and .[0].properties.route.enum == ["out_of_scope", "direct", "researcher"]
    and .[1].required == ["answerState", "answerMarkdown", "sources", "uncertainty"]
    and .[1].additionalProperties == false
    and .[1].properties.answerState.enum == ["supported", "unavailable", "out_of_scope"]
    and .[1].properties.sources.items.required == ["title", "url", "claim"]' \
    "$TEST_TEMP_DIR/claude.schemas.jsonl"
  jq -e \
    '."$schema" == "https://json-schema.org/draft/2020-12/schema"
     and .required == ["answerState", "answerMarkdown", "sources", "uncertainty"]' \
    "${PROJECT_ROOT}/plugins/me/skills/research/evals/result.schema.json"
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

@test "research evaluator: preserves dependent property-name maps while sanitizing schema values" {
  cat >"$TEST_TEMP_DIR/dependent-schema.ts" <<EOF
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
    dependentRequired: {
      "\$schema": ["format", "minLength"],
      format: ["\$schema"],
      minLength: ["format"],
    },
    dependencies: {
      "\$schema": ["format", "minLength"],
      format: {
        type: "object",
        format: "uri",
        properties: {
          minLength: { type: "string", minLength: 2 },
        },
        required: ["minLength"],
      },
      minLength: {
        type: "string",
        minLength: 3,
        "\$schema": "https://example.test/dependency",
      },
    },
  },
  workingDirectory: process.cwd(),
});
EOF
  run env RESEARCH_EVAL_CODEX_BIN="$TEST_TEMP_DIR/bin/codex" bun "$TEST_TEMP_DIR/dependent-schema.ts"
  [ "$status" -eq 0 ]
  jq -e '
    (.properties | has("format") and has("minLength") and has("$schema"))
    and (.required == ["format", "minLength", "$schema"])
    and (.dependentRequired == {
      "$schema": ["format", "minLength"],
      "format": ["$schema"],
      "minLength": ["format"]
    })
    and (.dependencies["$schema"] == ["format", "minLength"])
    and (.dependencies | has("format") and has("minLength"))
    and (.dependencies.format.required == ["minLength"])
    and (.dependencies.format | has("format") | not)
    and (.dependencies.format.properties | has("minLength"))
    and (.dependencies.format.properties.minLength | has("minLength") | not)
    and (.dependencies.minLength.type == "string")
    and (.dependencies.minLength | has("minLength") | not)
    and (.dependencies.minLength | has("$schema") | not)' \
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
