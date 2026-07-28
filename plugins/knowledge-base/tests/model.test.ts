import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readdir, readFile, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, expect, it } from "vitest";
import { ensureModel, MODEL_SPEC, verifyModelFile } from "../src/model.js";

const bytes = Buffer.from([0x47, 0x47, 0x55, 0x46, 0x01]);
const sha256 = createHash("sha256").update(bytes).digest("hex");

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
});
