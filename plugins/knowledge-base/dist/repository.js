import { lstat, stat } from "node:fs/promises";
import { join } from "node:path";
async function pathExists(path) {
    try {
        await stat(path);
        return true;
    }
    catch (error) {
        if (error.code === "ENOENT") {
            return false;
        }
        throw error;
    }
}
async function requireSuccess(result) {
    const value = await result;
    if (value.exitCode !== 0) {
        throw new Error(value.stderr.trim() || `command failed with exit code ${value.exitCode}`);
    }
    return value;
}
function assertMatchingOrigin(origin, repository) {
    const normalized = origin.replace(/\/$/, "").replace(/\.git$/, "");
    const allowedOrigins = new Set([
        repository,
        `https://github.com/${repository}`,
        `git@github.com:${repository}`,
        `ssh://git@github.com/${repository}`,
    ]);
    if (!allowedOrigins.has(normalized)) {
        throw new Error("origin does not match repository");
    }
}
async function assertDirectory(path) {
    let details;
    try {
        details = await lstat(path);
    }
    catch (error) {
        if (error.code === "ENOENT") {
            throw new Error(`required directory is missing: ${path}`);
        }
        throw error;
    }
    if (!details.isDirectory()) {
        throw new Error(`required path is not a directory: ${path}`);
    }
}
export async function assertRepositoryLayout(checkoutPath) {
    await assertDirectory(join(checkoutPath, "personal"));
    await assertDirectory(join(checkoutPath, "wooto"));
}
export async function setupRepository(repository, checkoutPath, runner) {
    await requireSuccess(runner.run("gh", ["auth", "status"]));
    if (!(await pathExists(checkoutPath))) {
        await requireSuccess(runner.run("gh", ["repo", "clone", repository, checkoutPath]));
    }
    else {
        await requireSuccess(runner.run("git", ["rev-parse", "--is-inside-work-tree"], { cwd: checkoutPath }));
        const origin = await requireSuccess(runner.run("git", ["remote", "get-url", "origin"], { cwd: checkoutPath }));
        assertMatchingOrigin(origin.stdout.trim(), repository);
    }
    await assertRepositoryLayout(checkoutPath);
}
export async function syncRepository(checkoutPath, runner) {
    await requireSuccess(runner.run("git", ["pull", "--ff-only"], { cwd: checkoutPath }));
}
//# sourceMappingURL=repository.js.map