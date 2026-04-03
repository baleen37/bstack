#!/usr/bin/env bash
set -euo pipefail

ROOT="plugins/ralph"

# Pre-check: files exist
for f in "$ROOT/skills/ralph/SKILL.md" "$ROOT/skills/ralph-cancel/SKILL.md" "$ROOT/hooks/ralph-persist.ts" "$ROOT/hooks/hooks.json" "$ROOT/.claude-plugin/plugin.json"; do
  [[ -f "$f" ]] || { echo "MISSING: $f" >&2; exit 1; }
done

# Skill bytes (loaded into LLM context — primary optimization target)
SKILL_BYTES=$(wc -c < "$ROOT/skills/ralph/SKILL.md" | tr -d ' ')
SKILL_LINES=$(wc -l < "$ROOT/skills/ralph/SKILL.md" | tr -d ' ')

# Cancel skill bytes
CANCEL_BYTES=$(wc -c < "$ROOT/skills/ralph-cancel/SKILL.md" | tr -d ' ')

# Hook bytes (runtime, not LLM context)
HOOK_BYTES=$(wc -c < "$ROOT/hooks/ralph-persist.ts" | tr -d ' ')
HOOK_LINES=$(wc -l < "$ROOT/hooks/ralph-persist.ts" | tr -d ' ')

# Total plugin bytes
TOTAL=$((SKILL_BYTES + CANCEL_BYTES + HOOK_BYTES))

# Validate: SKILL.md has frontmatter
head -1 "$ROOT/skills/ralph/SKILL.md" | grep -q '^---' || { echo "ERROR: SKILL.md missing frontmatter" >&2; exit 1; }

# Validate: hooks.json is valid JSON
jq empty "$ROOT/hooks/hooks.json" 2>/dev/null || { echo "ERROR: hooks.json invalid" >&2; exit 1; }

# Validate: TypeScript compiles
# Validate: TypeScript parses (dry-run with empty stdin)
echo '{}' | bun run "$ROOT/hooks/ralph-persist.ts" >/dev/null 2>&1 || { echo "ERROR: TS runtime error" >&2; exit 1; }

# Run tests
bats tests/ralph_persist.bats tests/ralph_hooks_json.bats >/dev/null 2>&1 || { echo "ERROR: tests failed" >&2; exit 1; }

echo "METRIC skill_bytes=$SKILL_BYTES"
echo "METRIC skill_lines=$SKILL_LINES"
echo "METRIC cancel_bytes=$CANCEL_BYTES"
echo "METRIC hook_bytes=$HOOK_BYTES"
echo "METRIC hook_lines=$HOOK_LINES"
echo "METRIC total_bytes=$TOTAL"
