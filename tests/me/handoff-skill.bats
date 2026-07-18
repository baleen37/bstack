#!/usr/bin/env bats

load ../helpers/bats_helper

setup() {
    SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/handoff/SKILL.md"
    SETUP_SKILL_FILE="${PROJECT_ROOT}/plugins/me/skills/setup/SKILL.md"
    SETTINGS_UPDATER="${PROJECT_ROOT}/plugins/me/skills/setup/configure-handoff-directory.mjs"
    OUTPUT_FIXTURE="${PROJECT_ROOT}/tests/fixtures/handoff/compound-user-direction.md"
    TEST_TEMP_DIR="$(mktemp -d -t handoff-test.XXXXXX)"
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "me: handoff emits each core heading exactly once" {
    for heading in "Task" "Completed" "Current State" "Next Steps"; do
        [ "$(grep -c "^## ${heading}$" "$SKILL_FILE")" -eq 1 ]
        [ "$(grep -c "^## ${heading}$" "$OUTPUT_FIXTURE")" -eq 1 ]
    done
}

@test "me: handoff has one resume protocol without overlapping sections" {
    grep -q '^## Resume Protocol$' "$SKILL_FILE"
    run grep -q '^## Resume Prompt$' "$SKILL_FILE"
    assert_failure
    run grep -q '^## Resume Checkpoint$' "$SKILL_FILE"
    assert_failure
}

@test "me: handoff preserves XDG write-only boundaries" {
    grep -Fq '${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff' "$SKILL_FILE"
    grep -q 'write-only' "$SKILL_FILE"
    grep -q 'Does not start a new session or read prior handoffs' "$SKILL_FILE"
}

@test "me: handoff resolves XDG output once and reuses HANDOFF_DIR" {
    [ "$(grep -Fc 'HANDOFF_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/bstack/handoff"' "$SKILL_FILE")" -eq 1 ]
    grep -Fq '$HANDOFF_DIR/YYYY-MM-DD-HHmm-<topic>.md' "$SKILL_FILE"
    grep -Fq 'Writes a file under `$HANDOFF_DIR`' "$SKILL_FILE"
    grep -Fq 'mkdir -p "$HANDOFF_DIR"' "$SKILL_FILE"
}

@test "me: setup resolves custom XDG handoff directory and preserves unrelated directories" {
    [ -f "$SETTINGS_UPDATER" ]
    grep -Fq 'configure-handoff-directory.mjs' "$SETUP_SKILL_FILE"

    settings_file="$TEST_TEMP_DIR/settings.json"
    printf '%s\n' '{"permissions":{"additionalDirectories":["/keep/me/","~/.local/share/bstack/handoff/"]}}' > "$settings_file"

    run env HOME="$TEST_TEMP_DIR/home" XDG_DATA_HOME="$TEST_TEMP_DIR/custom-data" \
        node "$SETTINGS_UPDATER" "$settings_file"
    assert_success

    run node -e '
        const fs = require("node:fs");
        const settings = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const dirs = settings.permissions.additionalDirectories;
        if (dirs.length !== 2 || dirs[0] !== "/keep/me/" || dirs[1] !== process.argv[2]) process.exit(1);
    ' "$settings_file" "$TEST_TEMP_DIR/custom-data/bstack/handoff/"
    assert_success
}

@test "me: handoff distinguishes temporary context from permanent rules" {
    grep -q 'AGENTS.md' "$SKILL_FILE"
    grep -q 'CLAUDE.md' "$SKILL_FILE"
    grep -q 'First action' "$SKILL_FILE"
    grep -q 'Last verified' "$SKILL_FILE"
}

@test "me: handoff preserves user direction and derives one safe first action" {
    grep -Fq 'preserve the full instruction verbatim as `User direction`' "$SKILL_FILE"
    grep -Fq 'Derive one singular `First action`' "$SKILL_FILE"
    grep -Fq 'Put later required actions after it.' "$SKILL_FILE"
    grep -Fq 'Do not invent a command when none was supplied.' "$SKILL_FILE"
    grep -Fq 'First action: <the exact work action to start after the Resume Protocol>' "$SKILL_FILE"
    run grep -Fq 'First action: <the exact action to resume safely, including any required preflight re-check>' "$SKILL_FILE"
    assert_failure
    run grep -q 'make it the `First action`' "$SKILL_FILE"
    assert_failure
}


@test "me: representative output separates compound direction without placeholders or empty sections" {
    [ "$(grep -Fc '1. First action: Verify the merge.' "$OUTPUT_FIXTURE")" -eq 1 ]
    grep -Fq 'User direction: verify merge, then deploy beta (from user at handoff time)' "$OUTPUT_FIXTURE"
    grep -Fq '2. Deploy beta after merge verification succeeds' "$OUTPUT_FIXTURE"

    run grep -Eq 'TODO|N/A|\.\.\.|<[^>]+>' "$OUTPUT_FIXTURE"
    assert_failure

    run awk '
        /^## / {
            if (section != "" && content == 0) exit 1
            section = $0
            content = 0
            next
        }
        section != "" && NF > 0 { content++ }
        END { if (section != "" && content == 0) exit 1 }
    ' "$OUTPUT_FIXTURE"
    assert_success
}

@test "me: saved artifact contains the resume gate in required order" {
    gate='Resume gate: compare recorded worktree/branch/commit → re-run Last verified → report drift or mismatch → only then start First action.'
    grep -Fq "$gate" "$SKILL_FILE"
    grep -Fq "$gate" "$OUTPUT_FIXTURE"

    gate_line="$(grep -nF "$gate" "$OUTPUT_FIXTURE" | cut -d: -f1)"
    next_steps_line="$(grep -n '^## Next Steps$' "$OUTPUT_FIXTURE" | cut -d: -f1)"
    [ "$gate_line" -lt "$next_steps_line" ]
}

@test "me: handoff is explicit-only and pickup is not user-facing" {
    run grep -Fq 'or before ending' "$SKILL_FILE"
    assert_failure
    [ ! -d "${PROJECT_ROOT}/plugins/me/skills/pickup" ]

    run grep -Eq '^\| `pickup` \|' "${PROJECT_ROOT}/README.md"
    assert_failure
    run grep -Eq '^- `pickup`' "${PROJECT_ROOT}/plugins/me/README.md"
    assert_failure
}
