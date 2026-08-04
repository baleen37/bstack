#!/bin/bash
# Autoresearch Context Injection Hook (UserPromptSubmit)
#
# When autoresearch mode is active (.autoresearch/autoresearch.md exists
# and no .autoresearch/off sentinel), injects a reminder into every user
# message so the agent stays in the loop.

if [ -f ".autoresearch/autoresearch.md" ] && [ ! -f ".autoresearch/off" ]; then
  cat << 'EOF'
## Autoresearch Mode (ACTIVE)
You are in autoresearch mode. Read .autoresearch/autoresearch.md for your objective and rules.
Use .autoresearch/autoresearch.jsonl for state. NEVER STOP until interrupted.
Run experiments, log results, keep winners, discard losers. Loop forever.
If .autoresearch/ideas.md exists, use it for experiment inspiration.
User messages during experiments are steers — finish your current experiment, log it, then incorporate the user's idea in the next experiment.
EOF
fi
