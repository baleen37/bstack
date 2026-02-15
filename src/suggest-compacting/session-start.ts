import fs from 'fs/promises';
import { isValidSessionId } from './lib/state.js';

interface SessionStartInput {
  session_id: string;
  transcript_path: string;
}

async function main() {
  const input = JSON.parse(await readStdin()) as SessionStartInput;

  if (!isValidSessionId(input.session_id)) {
    console.error(`Invalid session_id: ${input.session_id}`);
    process.exit(1);
  }

  const envFile = process.env.CLAUDE_ENV_FILE;
  if (envFile) {
    await fs.appendFile(envFile, `CLAUDE_SESSION_ID=${input.session_id}\n`);
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
