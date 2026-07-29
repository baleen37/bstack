import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
export class ModelValidationError extends Error {
}
export async function verifyModelFile(file, expected) {
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
        throw new ModelValidationError(`model size mismatch: expected ${expected.size}, got ${size}`);
    }
    if (magicLength !== magic.length || !magic.equals(Buffer.from("GGUF"))) {
        throw new ModelValidationError("model file is missing GGUF magic");
    }
    if (hash.digest("hex") !== expected.sha256) {
        throw new ModelValidationError("model SHA-256 mismatch");
    }
}
//# sourceMappingURL=model-verify.js.map