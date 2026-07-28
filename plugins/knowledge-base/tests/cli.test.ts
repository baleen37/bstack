import { describe, expect, it, vi } from "vitest";
import { runCli } from "../src/cli.js";
import type { KnowledgeBaseServices } from "../src/services.js";

function memoryIo() {
  const stdout: string[] = [];
  const stderr: string[] = [];
  return {
    io: {
      stdout: (text: string) => stdout.push(text),
      stderr: (text: string) => stderr.push(text),
    },
    stdout: () => stdout.join(""),
    stderr: () => stderr.join(""),
  };
}

function fakeServices(
  overrides: Partial<KnowledgeBaseServices> = {},
): KnowledgeBaseServices {
  return {
    setup: vi.fn().mockResolvedValue({
      repository: "owner/repo",
      checkoutPath: "/knowledge-base",
      defaultScope: "all",
    }),
    pull: vi.fn().mockResolvedValue(undefined),
    index: vi.fn().mockResolvedValue({ indexed: 1 }),
    search: vi.fn().mockResolvedValue([{ title: "배포 절차" }]),
    get: vi.fn().mockResolvedValue({ title: "배포 절차", body: "내용" }),
    status: vi.fn().mockResolvedValue({ healthy: true }),
    startMcp: vi.fn().mockResolvedValue(undefined),
    ...overrides,
  };
}

describe("knowledge-base CLI", () => {
  it("requires --repo on first setup", async () => {
    const output = memoryIo();

    await expect(runCli(["setup"], fakeServices(), output.io)).resolves.toBe(2);

    expect(output.stderr()).toContain("--repo <owner/repo> is required");
  });

  it("passes setup repository and optional absolute path to the service", async () => {
    const services = fakeServices();
    const output = memoryIo();

    await expect(runCli(
      ["setup", "--repo", "owner/repo", "--path", "/knowledge-base"],
      services,
      output.io,
    )).resolves.toBe(0);

    expect(services.setup).toHaveBeenCalledWith({
      repository: "owner/repo",
      path: "/knowledge-base",
    });
    expect(output.stdout()).toContain("owner/repo");
  });

  it("defaults search scope to all and limit to 10", async () => {
    const services = fakeServices();

    await runCli(["search", "배포 절차", "--json"], services, memoryIo().io);

    expect(services.search).toHaveBeenCalledWith("배포 절차", "all", 10);
  });

  it("rejects a whitespace-only search query before calling the service", async () => {
    const services = fakeServices();
    const output = memoryIo();

    await expect(runCli(["search", "   "], services, output.io)).resolves.toBe(2);

    expect(output.stderr()).toContain("<query> must not be empty");
    expect(services.search).not.toHaveBeenCalled();
  });

  it("prints search results as JSON only when requested", async () => {
    const output = memoryIo();

    await expect(runCli(
      ["search", "배포 절차", "--json"],
      fakeServices(),
      output.io,
    )).resolves.toBe(0);

    expect(JSON.parse(output.stdout())).toEqual([{ title: "배포 절차" }]);
  });

  it.each(["team", "", "ALL"])("rejects invalid scope %j", async (scope) => {
    const services = fakeServices();
    const output = memoryIo();

    await expect(runCli(
      ["search", "배포", "--scope", scope],
      services,
      output.io,
    )).resolves.toBe(2);

    expect(output.stderr()).toContain("--scope must be personal, wooto, or all");
    expect(services.search).not.toHaveBeenCalled();
  });

  it.each(["0", "51", "1.5", "many"])("rejects invalid search limit %s", async (limit) => {
    const services = fakeServices();
    const output = memoryIo();

    await expect(runCli(
      ["search", "배포", "--limit", limit],
      services,
      output.io,
    )).resolves.toBe(2);

    expect(output.stderr()).toContain("--limit must be an integer from 1 to 50");
    expect(services.search).not.toHaveBeenCalled();
  });

  it("passes get line limits to the service", async () => {
    const services = fakeServices();

    await expect(runCli(
      ["get", "qmd://personal/guide.md", "--from-line", "2", "--max-lines", "20"],
      services,
      memoryIo().io,
    )).resolves.toBe(0);

    expect(services.get).toHaveBeenCalledWith("qmd://personal/guide.md", 2, 20);
  });

  it("rejects get without a reference", async () => {
    const services = fakeServices();
    const output = memoryIo();

    await expect(runCli(["get"], services, output.io)).resolves.toBe(2);

    expect(output.stderr()).toContain("<ref> is required");
    expect(services.get).not.toHaveBeenCalled();
  });

  it("never syncs after a failed fast-forward pull", async () => {
    const services = fakeServices({
      pull: vi.fn().mockRejectedValue(new Error("non-fast-forward")),
    });

    await expect(runCli(["sync"], services, memoryIo().io)).resolves.toBe(1);

    expect(services.index).not.toHaveBeenCalled();
  });

  it("syncs then indexes every scope without force", async () => {
    const calls: string[] = [];
    const services = fakeServices({
      pull: vi.fn(async () => { calls.push("pull"); }),
      index: vi.fn(async (scope: string, force: boolean) => {
        calls.push(`index:${scope}:${force}`);
        return {};
      }),
    });

    await expect(runCli(["sync"], services, memoryIo().io)).resolves.toBe(0);

    expect(calls).toEqual(["pull", "index:all:false"]);
  });

  it("prints the package version", async () => {
    const output = memoryIo();

    await expect(runCli(["--version"], fakeServices(), output.io)).resolves.toBe(0);

    expect(output.stdout()).toMatch(/^17\.35\.0\n$/);
  });

  it("returns usage error for an unknown command", async () => {
    const output = memoryIo();

    await expect(runCli(["publish"], fakeServices(), output.io)).resolves.toBe(2);

    expect(output.stderr()).toContain("unknown command: publish");
  });

  it("delegates mcp before producing output", async () => {
    const output = memoryIo();
    const services = fakeServices();

    await expect(runCli(["mcp"], services, output.io)).resolves.toBe(0);

    expect(services.startMcp).toHaveBeenCalledOnce();
    expect(output.stdout()).toBe("");
  });
});
