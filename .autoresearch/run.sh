#!/usr/bin/env bash
set -euo pipefail

DIR="plugins/me/skills/create-pr"

# Total bytes (primary metric)
TOTAL_BYTES=$(cat "$DIR/SKILL.md" "$DIR"/scripts/*.sh 2>/dev/null | wc -c | tr -d ' ')
echo "METRIC total_bytes=$TOTAL_BYTES"

# Secondary metrics
LINE_COUNT=$(cat "$DIR/SKILL.md" "$DIR"/scripts/*.sh 2>/dev/null | wc -l | tr -d ' ')
echo "METRIC line_count=$LINE_COUNT"

FILE_COUNT=$(find "$DIR" -type f \( -name "*.md" -o -name "*.sh" \) | wc -l | tr -d ' ')
echo "METRIC file_count=$FILE_COUNT"

WORD_COUNT=$(cat "$DIR/SKILL.md" "$DIR"/scripts/*.sh 2>/dev/null | wc -w | tr -d ' ')
echo "METRIC word_count=$WORD_COUNT"

# Validity checks
echo "--- Validity Checks ---"

# Check SKILL.md frontmatter
if head -1 "$DIR/SKILL.md" | grep -q '^---'; then
  echo "OK: SKILL.md has frontmatter"
else
  echo "FAIL: SKILL.md missing frontmatter" >&2
  exit 1
fi

# ShellCheck
SHELLCHECK_FAIL=0
SCRIPTS_DIR="$DIR/scripts"
for f in "$SCRIPTS_DIR"/*.sh; do
  if ! (cd "$SCRIPTS_DIR" && shellcheck -x "$(basename "$f")") > /dev/null 2>&1; then
    echo "FAIL: shellcheck $f" >&2
    (cd "$SCRIPTS_DIR" && shellcheck -x "$(basename "$f")") >&2 || true
    SHELLCHECK_FAIL=1
  fi
done
if [[ $SHELLCHECK_FAIL -eq 0 ]]; then
  echo "OK: All scripts pass shellcheck"
else
  exit 1
fi

echo "--- Done ---"
