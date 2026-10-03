import { existsSync, mkdirSync, renameSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const topic = process.argv[2];
if (!topic || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(topic)) {
  console.error("usage: resolve-workspace.ts TOPIC (lowercase dash-case)");
  process.exit(2);
}

const home = process.env.HOME || homedir();
const workspace = join(home, ".skills", "learn", topic);
const legacyWorkspace = join(home, ".bstack", "learn", topic);

if (existsSync(workspace) && existsSync(legacyWorkspace)) {
  console.error(`both .bstack and .skills learn workspaces exist for ${topic}`);
  process.exit(2);
}

if (existsSync(legacyWorkspace)) {
  mkdirSync(dirname(workspace), { recursive: true });
  renameSync(legacyWorkspace, workspace);
} else {
  mkdirSync(workspace, { recursive: true });
}

console.log(workspace);
