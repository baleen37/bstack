import { spawn } from "node:child_process";
import type { CommandRunner, RunResult } from "./types.js";

export const commandRunner: CommandRunner = {
  run(command, args, options) {
    return new Promise<RunResult>((resolve, reject) => {
      const child = spawn(command, args, {
        cwd: options?.cwd,
        shell: false,
        stdio: ["ignore", "pipe", "pipe"],
      });
      const stdout: Buffer[] = [];
      const stderr: Buffer[] = [];

      child.stdout?.on("data", (chunk: Buffer) => stdout.push(chunk));
      child.stderr?.on("data", (chunk: Buffer) => stderr.push(chunk));
      child.once("error", reject);
      child.once("close", (exitCode) => {
        resolve({
          exitCode: exitCode ?? 1,
          stdout: Buffer.concat(stdout).toString("utf8"),
          stderr: Buffer.concat(stderr).toString("utf8"),
        });
      });
    });
  },
};
