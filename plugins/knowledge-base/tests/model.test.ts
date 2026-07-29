import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ensureModel, MODEL_SPEC, verifyModelFile } from "../src/model.js";

const bytes = Buffer.from([0x47, 0x47, 0x55, 0x46, 0x01]);
const sha256 = createHash("sha256").update(bytes).digest("hex");

async function withMockedEnsureModel(
  verify: (file: string) => Promise<void>,
  io: Record<string, unknown>,
  test: (ensure: typeof ensureModel) => Promise<void>,
): Promise<void> {
  vi.resetModules();
  vi.doMock("../src/model-verify.js", async () => ({
    ...await vi.importActual("../src/model-verify.js"),
    verifyModelFile: verify,
  }));
  vi.doMock("../src/model-io.js", async () => ({
    ...await vi.importActual("../src/model-io.js"),
    ...io,
  }));
  const { ensureModel: mockedEnsureModel } = await import("../src/model.js");
  await test(mockedEnsureModel);
}

function missingFileError(): NodeJS.ErrnoException {
  return Object.assign(new Error("missing model"), { code: "ENOENT" });
}

afterEach(() => {
  vi.doUnmock("../src/model-io.js");
  vi.doUnmock("../src/model-verify.js");
  vi.doUnmock("node:fs/promises");
  vi.resetModules();
});

describe("model artifact", () => {
  it("accepts matching size, hash, and GGUF magic", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-"));
    const file = join(root, "model.gguf");
    await writeFile(file, bytes);

    await expect(verifyModelFile(file, {
      size: bytes.length,
      sha256,
    })).resolves.toBeUndefined();
  });

  it.each([
    { size: bytes.length + 1, sha256 },
    { size: bytes.length, sha256: "0".repeat(64) },
  ])("rejects an artifact with an invalid size or hash", async (expected) => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-bad-"));
    const file = join(root, "model.gguf");
    await writeFile(file, bytes);

    await expect(verifyModelFile(file, expected)).rejects.toThrow();
  });

  it("rejects an artifact without GGUF magic", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-magic-"));
    const file = join(root, "model.gguf");
    await writeFile(file, Buffer.from([0x00, 0x47, 0x55, 0x46, 0x01]));

    await expect(verifyModelFile(file, {
      size: bytes.length,
      sha256,
    })).rejects.toThrow();
  });

  it("uses a pinned model revision", () => {
    expect(MODEL_SPEC).toEqual({
      url: "https://huggingface.co/n24q02m/Qwen3-Embedding-0.6B-GGUF/resolve/4aea43eaa9633282b1eee7be8cf7ac59a0011709/qwen3-embedding-0.6b-q4-k-m.gguf",
      size: 396_474_496,
      sha256: "690ce73e3716962cbdbfb0dcb9ea6ad633430101ba3247c6e6d36cbdd06f3871",
    });
    expect(Object.isFrozen(MODEL_SPEC)).toBe(true);
    expect(MODEL_SPEC.url).toContain(
      "/resolve/4aea43eaa9633282b1eee7be8cf7ac59a0011709/",
    );
    expect(MODEL_SPEC.url).not.toContain("/resolve/main/");
    expect(MODEL_SPEC.sha256).toHaveLength(64);
  });

  it("preserves the destination and removes its temporary file after a failed download", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-download-"));
    const destination = join(root, "models", "model.gguf");
    const existing = Buffer.from("existing invalid model");
    await mkdir(dirname(destination), { recursive: true });
    await writeFile(destination, existing);
    const requests: string[] = [];
    const fetchImpl: typeof fetch = async (input) => {
      requests.push(input.toString());
      return new Response(bytes);
    };

    await expect(ensureModel(destination, fetchImpl)).rejects.toThrow();

    expect(requests).toEqual([MODEL_SPEC.url]);
    await expect(readFile(destination)).resolves.toEqual(existing);
    await expect(readdir(dirname(destination))).resolves.toEqual(["model.gguf"]);
  });

  it("returns a verified existing destination without fetching", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-existing-"));
    const destination = join(root, "model.gguf");
    const existing = Buffer.from("existing valid model");
    await writeFile(destination, existing);
    const fetchImpl: typeof fetch = async () => {
      throw new Error("fetch must not be called for a valid model");
    };

    await withMockedEnsureModel(async () => undefined, {}, async (ensure) => {
      await expect(ensure(destination, fetchImpl)).resolves.toBe(destination);
    });
    await expect(readFile(destination)).resolves.toEqual(existing);
  });

  it("leaves the verified renamed destination when directory sync fails", async () => {
    const directorySyncError = new Error("directory sync failed");
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-directory-sync-"));
    const destination = join(root, "model.gguf");

    await withMockedEnsureModel(
      async (file) => {
        if (file === destination) throw missingFileError();
      },
      { syncDirectory: async () => { throw directorySyncError; } },
      async (ensure) => {
        await expect(ensure(destination, async () => new Response(bytes)))
          .rejects.toBe(directorySyncError);
      },
    );
    await expect(readFile(destination)).resolves.toEqual(bytes);
    await expect(readdir(root)).resolves.toEqual(["model.gguf"]);
  });

  it("preserves the download error when temporary-file cleanup also fails", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-cleanup-"));
    const destination = join(root, "model.gguf");
    const cleanupError = new Error("temporary cleanup failed");
    await withMockedEnsureModel(
      async (file) => {
        if (file === destination) throw missingFileError();
        throw new Error("invalid downloaded model");
      },
      { removeTemporary: async () => { throw cleanupError; } },
      async (ensure) => {
        try {
          await ensure(destination, async () => new Response(bytes));
          expect.unreachable("the invalid fixture must not install");
        } catch (error) {
          expect(error).toBeInstanceOf(AggregateError);
          expect((error as AggregateError).errors).toContain(cleanupError);
          expect((error as AggregateError).errors).toContainEqual(
            expect.objectContaining({ message: "invalid downloaded model" }),
          );
        }
      },
    );
    expect(await readdir(root)).toHaveLength(1);
  });

  it("preserves directory sync and close errors", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-directory-errors-"));
    const syncError = new Error("directory sync failed");
    const closeError = new Error("directory close failed");
    vi.resetModules();
    vi.doMock("node:fs/promises", async () => {
      const actual = await vi.importActual<typeof import("node:fs/promises")>(
        "node:fs/promises",
      );
      return {
        ...actual,
        open: async (file: string, ...args: unknown[]) => {
          if (file === root) {
            return {
              sync: async () => { throw syncError; },
              close: async () => { throw closeError; },
            };
          }
          return actual.open(file, ...(args as []));
        },
      };
    });
    const { syncDirectory } = await import("../src/model-io.js");

    await expect(syncDirectory(root)).rejects.toSatisfy((error: unknown) => {
      return error instanceof AggregateError
        && error.errors.includes(syncError)
        && error.errors.includes(closeError);
    });
  });

  it("returns a directory close error when sync succeeds", async () => {
    const root = await mkdtemp(join(tmpdir(), "knowledge-model-directory-close-"));
    const closeError = new Error("directory close failed");
    vi.resetModules();
    vi.doMock("node:fs/promises", async () => {
      const actual = await vi.importActual<typeof import("node:fs/promises")>(
        "node:fs/promises",
      );
      return {
        ...actual,
        open: async (file: string, ...args: unknown[]) => {
          if (file === root) {
            return {
              sync: async () => undefined,
              close: async () => { throw closeError; },
            };
          }
          return actual.open(file, ...(args as []));
        },
      };
    });
    const { syncDirectory } = await import("../src/model-io.js");

    await expect(syncDirectory(root)).rejects.toBe(closeError);
  });
});
