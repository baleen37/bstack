import { mkdir, mkdtemp, readFile, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { setupRepository, syncRepository } from "../src/repository.js";
import type { CommandRunner, RunResult } from "../src/types.js";

type Call = [string, readonly string[], { cwd?: string } | undefined];

class RecordingRunner implements CommandRunner {
  readonly calls: Call[] = [];

  constructor(
    private readonly execute: (
      command: string,
      args: readonly string[],
      options?: { cwd?: string },
    ) => Promise<RunResult>,
  ) {}

  async run(
    command: string,
    args: readonly string[],
    options?: { cwd?: string },
  ): Promise<RunResult> {
    this.calls.push([command, args, options]);
    return this.execute(command, args, options);
  }
}

const success = (stdout = ""): RunResult => ({ exitCode: 0, stdout, stderr: "" });

describe("repository", () => {
  it("authenticates and clones a missing checkout before requiring both scopes", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-base-repository-"));
    const checkoutPath = join(root, "checkout");
    const runner = new RecordingRunner(async (command, args) => {
      if (command === "gh" && args[0] === "repo") {
        await mkdir(join(checkoutPath, "personal"), { recursive: true });
        await mkdir(join(checkoutPath, "wooto"), { recursive: true });
      }
      return success();
    });

    await setupRepository("baleen37/knowledge-base", checkoutPath, runner);

    expect(runner.calls).toContainEqual(["gh", ["auth", "status"], undefined]);
    expect(runner.calls).toContainEqual([
      "gh",
      ["repo", "clone", "baleen37/knowledge-base", checkoutPath],
      undefined,
    ]);
  });

  it("refuses an existing checkout with a different origin without changing it", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-base-repository-"));
    const checkoutPath = join(root, "checkout");
    const sentinel = join(checkoutPath, "keep.txt");
    await mkdir(checkoutPath);
    await writeFile(sentinel, "preserve me");
    const runner = new RecordingRunner(async (command, args) => {
      if (command === "git" && args[0] === "remote") {
        return success("git@github.com:someone-else/repository.git\\n");
      }
      return success("true\\n");
    });

    await expect(
      setupRepository("baleen37/knowledge-base", checkoutPath, runner),
    ).rejects.toThrow("origin does not match repository");
    expect(await readFile(sentinel, "utf8")).toBe("preserve me");
  });

  it("rejects a collection root symlink", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-base-repository-"));
    const checkoutPath = join(root, "checkout");
    const personalTarget = join(root, "personal-target");
    await mkdir(personalTarget, { recursive: true });
    await mkdir(join(checkoutPath, "wooto"), { recursive: true });
    await symlink(personalTarget, join(checkoutPath, "personal"));
    const runner = new RecordingRunner(async (command, args) => {
      if (command === "git" && args[0] === "remote") {
        return success("git@github.com:baleen37/knowledge-base.git\n");
      }
      return success("true\n");
    });

    await expect(
      setupRepository("baleen37/knowledge-base", checkoutPath, runner),
    ).rejects.toThrow("required path is not a directory");
  });

  it("syncs only with a fast-forward pull", async () => {
    const checkoutPath = "/tmp/knowledge-base";
    const runner = new RecordingRunner(async () => success());

    await syncRepository(checkoutPath, runner);

    expect(runner.calls).toEqual([
      ["git", ["pull", "--ff-only"], { cwd: checkoutPath }],
    ]);
  });
});
