import fs from 'fs/promises';
import path from 'path';

interface ToolCountState {
  count: number;
  sessionId: string;
}

const STATE_DIR = path.join(process.env.HOME || '', '.claude', 'suggest-compacting');
const STATE_FILE = (sessionId: string) => path.join(STATE_DIR, `tool-count-${sessionId}.txt`);

// Session ID validation (alphanumeric, underscore, hyphen only)
export function isValidSessionId(sessionId: string): boolean {
  return /^[a-zA-Z0-9_-]+$/.test(sessionId);
}

// Read state
export async function readState(sessionId: string): Promise<ToolCountState | null> {
  const filepath = STATE_FILE(sessionId);
  try {
    const content = await fs.readFile(filepath, 'utf-8');
    const count = parseInt(content.trim(), 10);
    return { count, sessionId };
  } catch {
    return null;
  }
}

// Write state
export async function writeState(state: ToolCountState): Promise<void> {
  await fs.mkdir(STATE_DIR, { recursive: true });
  const filepath = STATE_FILE(state.sessionId);
  await fs.writeFile(filepath, state.count.toString(), 'utf-8');
}

// Increment state
export async function incrementState(sessionId: string): Promise<ToolCountState> {
  const current = await readState(sessionId);
  const newState: ToolCountState = {
    count: (current?.count ?? 0) + 1,
    sessionId,
  };
  await writeState(newState);
  return newState;
}
