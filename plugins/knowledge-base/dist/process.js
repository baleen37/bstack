import { spawn } from "node:child_process";
export const commandRunner = {
    run(command, args, options) {
        return new Promise((resolve, reject) => {
            const child = spawn(command, args, {
                cwd: options?.cwd,
                shell: false,
                stdio: ["ignore", "pipe", "pipe"],
            });
            const stdout = [];
            const stderr = [];
            child.stdout?.on("data", (chunk) => stdout.push(chunk));
            child.stderr?.on("data", (chunk) => stderr.push(chunk));
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
//# sourceMappingURL=process.js.map