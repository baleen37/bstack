#!/usr/bin/env bash
set -euo pipefail

SKILL="plugins/me/skills/create-pr/SKILL.md"
SCRIPTS_DIR="plugins/me/skills/create-pr/scripts"

# Primary: SKILL.md bytes (this is what loads into LLM context)
SKILL_BYTES=$(wc -c < "$SKILL" | tr -d ' ')
echo "METRIC skill_bytes=$SKILL_BYTES"

# Secondary
SKILL_LINES=$(wc -l < "$SKILL" | tr -d ' ')
echo "METRIC skill_lines=$SKILL_LINES"
SKILL_WORDS=$(wc -w < "$SKILL" | tr -d ' ')
echo "METRIC skill_words=$SKILL_WORDS"
SCRIPT_BYTES=$(cat "$SCRIPTS_DIR"/*.sh 2>/dev/null | wc -c | tr -d ' ')
echo "METRIC script_bytes=$SCRIPT_BYTES"

# Validity
echo "--- Validity Checks ---"
head -1 "$SKILL" | grep -q '^---' || { echo "FAIL: missing frontmatter" >&2; exit 1; }
echo "OK: frontmatter"

FAIL=0
for f in "$SCRIPTS_DIR"/*.sh; do
  if ! (cd "$SCRIPTS_DIR" && shellcheck -x "$(basename "$f")") >/dev/null 2>&1; then
    echo "FAIL: shellcheck $(basename "$f")" >&2
    (cd "$SCRIPTS_DIR" && shellcheck -x "$(basename "$f")") >&2 || true
    FAIL=1
  fi
done
[[ $FAIL -eq 0 ]] && echo "OK: shellcheck" || exit 1
echo "--- Done ---"
