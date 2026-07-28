import { createHash, randomUUID } from "node:crypto";
import { createReadStream } from "node:fs";
import { mkdir, open, rename, rm } from "node:fs/promises";
import { basename, dirname, join } from "node:path";

class ModelValidationError extends Error {}

export const MODEL_SPEC = {
  url: "https://huggingface.co/n24q02m/Qwen3-Embedding-0.6B-GGUF/resolve/4aea43eaa9633282b1eee7be8cf7ac59a0011709/qwen3-embedding-0.6b-q4-k-m.gguf",
  size: 396_474_496,
  sha256: "690ce73e3716962cbdbfb0dcb9ea6ad633430101ba3247c6e6d36cbdd06f3871",
} as const;

export async function verifyModelFile(
  file: string,
  expected: { size: number; sha256: string },
): Promise<void> {
  const hash = createHash("sha256");
  const magic = Buffer.alloc(4);
  let size = 0;
  let magicLength = 0;

  for await (const chunk of createReadStream(file)) {
    size += chunk.length;
    hash.update(chunk);
    if (magicLength < magic.length) {
      const length = Math.min(chunk.length, magic.length - magicLength);
      chunk.copy(magic, magicLength, 0, length);
      magicLength += length;
    }
  }

  if (size !== expected.size) {
    throw new ModelValidationError(
      `model size mismatch: expected ${expected.size}, got ${size}`,
    );
  }
  if (magicLength !== magic.length || !magic.equals(Buffer.from("GGUF"))) {
    throw new ModelValidationError("model file is missing GGUF magic");
  }
  if (hash.digest("hex") !== expected.sha256) {
    throw new ModelValidationError("model SHA-256 mismatch");
  }
}

export async function ensureModel(
  destination: string,
  fetchImpl: typeof fetch = fetch,
): Promise<string> {
  try {
    await verifyModelFile(destination, MODEL_SPEC);
    return destination;
  } catch (error) {
    if (!(error instanceof ModelValidationError) && !isMissingFile(error)) {
      throw error;
    }
    // An absent or invalid artifact is replaced only after a complete download
    // has been synced and verified in a separate temporary file.
  }

  const directory = dirname(destination);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const temporary = join(
    directory,
    `.${basename(destination)}.${process.pid}.${randomUUID()}.tmp`,
  );
  let handle: Awaited<ReturnType<typeof open>> | undefined;

  try {
    handle = await open(temporary, "wx", 0o600);
    const response = await fetchImpl(MODEL_SPEC.url);
    if (!response.ok) {
      throw new Error(`model download failed with HTTP ${response.status}`);
    }
    if (response.body === null) {
      throw new Error("model download returned an empty body");
    }

    for await (const chunk of response.body) {
      await writeChunk(handle, chunk);
    }
    await handle.sync();
    await handle.close();
    handle = undefined;

    await verifyModelFile(temporary, MODEL_SPEC);
    await rename(temporary, destination);
    await syncDirectory(directory);
    return destination;
  } catch (error) {
    await handle?.close().catch(() => undefined);
    await rm(temporary, { force: true });
    throw error;
  }
}

function isMissingFile(error: unknown): error is NodeJS.ErrnoException {
  return typeof error === "object" && error !== null && "code" in error
    && error.code === "ENOENT";
}

async function writeChunk(
  handle: Awaited<ReturnType<typeof open>>,
  chunk: Uint8Array,
): Promise<void> {
  let offset = 0;
  while (offset < chunk.length) {
    const { bytesWritten } = await handle.write(
      chunk,
      offset,
      chunk.length - offset,
    );
    if (bytesWritten === 0) {
      throw new Error("model download write made no progress");
    }
    offset += bytesWritten;
  }
}

async function syncDirectory(directory: string): Promise<void> {
  const handle = await open(directory, "r");
  try {
    await handle.sync();
  } finally {
    await handle.close();
  }
}
