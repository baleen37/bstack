import { incrementState, isValidSessionId } from './lib/state.js';

interface PreToolUseInput {
  tool_name: string;
  session_id: string;
}

const DEFAULT_THRESHOLD = 50;
const REPEAT_THRESHOLD = 25;

async function main() {
  const input = JSON.parse(await readStdin()) as PreToolUseInput;

  const sessionId = input.session_id || process.env.CLAUDE_SESSION_ID;

  if (!sessionId || !isValidSessionId(sessionId)) {
    process.exit(0);
  }

  const state = await incrementState(sessionId);

  const threshold = parseInt(process.env.COMPACT_THRESHOLD || `${DEFAULT_THRESHOLD}`, 10);
  const shouldSuggest = state.count === threshold ||
                       (state.count > threshold && (state.count - threshold) % REPEAT_THRESHOLD === 0);

  if (shouldSuggest) {
    console.log(`\n--- Suggestion ---`);
    console.log(`You've made ${state.count} tool calls in this session.`);
    console.log(`Consider compacting your context to improve performance.`);
    console.log(`Use: /compact`);
    console.log(`------------------\n`);
  }
}

function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.on('data', (chunk) => data += chunk);
    process.stdin.on('end', () => resolve(data));
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
