import { randomUUID } from "node:crypto";
import { basename, dirname, join } from "node:path";
import { mkdir, open, removeTemporary, rename, syncDirectory } from "./model-io.js";
import { ModelValidationError, verifyModelFile } from "./model-verify.js";
export { verifyModelFile } from "./model-verify.js";
export const MODEL_SPEC = Object.freeze({
    url: "https://huggingface.co/n24q02m/Qwen3-Embedding-0.6B-GGUF/resolve/4aea43eaa9633282b1eee7be8cf7ac59a0011709/qwen3-embedding-0.6b-q4-k-m.gguf",
    size: 396_474_496,
    sha256: "690ce73e3716962cbdbfb0dcb9ea6ad633430101ba3247c6e6d36cbdd06f3871",
});
export async function ensureModel(destination, fetchImpl = fetch) {
    try {
        await verifyModelFile(destination, MODEL_SPEC);
        return destination;
    }
    catch (error) {
        if (!(error instanceof ModelValidationError) && !isMissingFile(error)) {
            throw error;
        }
        // An absent or invalid artifact is replaced only after a complete download
        // has been synced and verified in a separate temporary file.
    }
    const directory = dirname(destination);
    await mkdir(directory, { recursive: true, mode: 0o700 });
    const temporary = join(directory, `.${basename(destination)}.${process.pid}.${randomUUID()}.tmp`);
    let handle;
    let renamed = false;
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
        renamed = true;
        await syncDirectory(directory);
        return destination;
    }
    catch (error) {
        const cleanupErrors = [];
        if (handle !== undefined) {
            try {
                await handle.close();
            }
            catch (cleanupError) {
                cleanupErrors.push(cleanupError);
            }
        }
        if (!renamed) {
            try {
                await removeTemporary(temporary);
            }
            catch (cleanupError) {
                cleanupErrors.push(cleanupError);
            }
        }
        if (cleanupErrors.length > 0) {
            throw new AggregateError([error, ...cleanupErrors], "model installation failed and cleanup failed");
        }
        throw error;
    }
}
function isMissingFile(error) {
    return typeof error === "object" && error !== null && "code" in error
        && error.code === "ENOENT";
}
async function writeChunk(handle, chunk) {
    let offset = 0;
    while (offset < chunk.length) {
        const { bytesWritten } = await handle.write(chunk, offset, chunk.length - offset);
        if (bytesWritten === 0) {
            throw new Error("model download write made no progress");
        }
        offset += bytesWritten;
    }
}
//# sourceMappingURL=model.js.map