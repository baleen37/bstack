#!/usr/bin/env bats
# Test suite for tmux-workers SKILL.md correctness

load '../helpers/bats_helper'

setup() {
  export SKILL_MD="${BATS_TEST_DIRNAME}/../../plugins/me/skills/tmux-workers/SKILL.md"

  if [[ ! -f "$SKILL_MD" ]]; then
    skip "SKILL.md not found"
  fi

  export CONTENT
  CONTENT=$(cat "$SKILL_MD")
}

# --- File existence and frontmatter ---

@test "SKILL.md exists" {
  [ -f "$SKILL_MD" ]
}

@test "SKILL.md has YAML frontmatter with name field" {
  has_frontmatter_delimiter "$SKILL_MD"
  has_frontmatter_field "$SKILL_MD" "name"
}

@test "SKILL.md has YAML frontmatter with description field" {
  has_frontmatter_field "$SKILL_MD" "description"
}

@test "frontmatter name is tmux-workers" {
  grep -q '^name: tmux-workers' "$SKILL_MD"
}

@test "description starts with Use when" {
  grep -q '^description:.*Use when' "$SKILL_MD"
}

# --- Agent commands ---

@test "documents claude CLI non-interactive command" {
  grep -q 'claude.*-p' "$SKILL_MD"
}

@test "documents codex exec command (not bare codex)" {
  grep -q 'codex exec' "$SKILL_MD"
}

@test "documents gemini CLI non-interactive command" {
  grep -q 'gemini.*-p' "$SKILL_MD"
}

@test "claude command includes --dangerously-skip-permissions" {
  grep -q '\-\-dangerously-skip-permissions' "$SKILL_MD"
}

@test "codex command includes --full-auto" {
  grep -q '\-\-full-auto' "$SKILL_MD"
}

@test "gemini command includes --yolo" {
  grep -q '\-\-yolo' "$SKILL_MD"
}

# --- send-keys -l flag ---

@test "send-keys uses -l flag for literal input" {
  grep -q 'send-keys.*-l' "$SKILL_MD"
}

# --- Task file pattern ---

@test "uses task file pattern instead of inline" {
  grep -q 'TASK_FILE' "$SKILL_MD"
}

@test "task file cleanup is documented" {
  grep -q 'rm.*TASK_FILE\|TASK_FILE.*rm' "$SKILL_MD"
}

# --- Split pane pattern ---

@test "uses split-window not new-session for workers" {
  grep -q 'split-window' "$SKILL_MD"
}

@test "captures pane ID with -PF format" {
  grep -q '\-PF' "$SKILL_MD"
}

@test "uses pane_id format for stable identification" {
  grep -q 'pane_id' "$SKILL_MD"
}

# --- Layout ---

@test "documents horizontal split for first worker" {
  grep -q 'split-window.*-h' "$SKILL_MD"
}

@test "documents vertical split for additional workers" {
  grep -q 'split-window.*-v' "$SKILL_MD"
}

# --- Common Mistakes ---

@test "has Common Mistakes section" {
  grep -q '## Common Mistakes\|## Common mistakes' "$SKILL_MD"
}

@test "warns about bare codex vs codex exec" {
  grep -q 'codex exec\|TUI' "$SKILL_MD"
}

@test "warns about missing -l flag on send-keys" {
  grep -q 'send-keys.*-l\|literal' "$SKILL_MD"
}

# --- Fire-and-forget semantics ---

@test "does not use tmux wait-for (fire-and-forget)" {
  run grep 'tmux wait-for' "$SKILL_MD"
  [ "$status" -ne 0 ]
}

@test "does not use result file pattern (no -o FILE or > FILE for results)" {
  run grep -E '^\s*-o.*RESULT|>\s*"\$RESULT"' "$SKILL_MD"
  [ "$status" -ne 0 ]
}

# --- delegate-cli-agent should not exist ---

@test "delegate-cli-agent skill has been removed" {
  local OLD_SKILL="${BATS_TEST_DIRNAME}/../../plugins/me/skills/delegate-cli-agent/SKILL.md"
  [ ! -f "$OLD_SKILL" ]
}
